#!/usr/bin/env ruby

module Task
  def self.load(hiiro)
    hiiro.log "Plugin loaded: #{name}"

    hiiro.load_plugin(Tmux)
    attach_methods(hiiro)
    add_subcommands(hiiro)
  end

  def self.add_subcommands(hiiro)
    hiiro.add_subcmd(:task) do |*args|
      tasks = hiiro.task_manager

      case args
      in []
        tasks.help
      in ['list'] | ['ls']
        tasks.list_trees
      in ['start', task_name]
        tasks.start_task(task_name)
      in ['start', task_name, tree]
        tasks.start_task(task_name, tree: tree)
      in ['app', app_name]
        tasks.open_app(app_name)
      in ['apps']
        tasks.list_configured_apps
      in ['save']
        tasks.save_current
      in ['status'] | ['st']
        tasks.status
      in ['stop']
        tasks.stop_current
      else
        puts "Unknown task subcommand: #{args.inspect}"
        tasks.help
      end
    end
  end

  def self.attach_methods(hiiro)
    hiiro.instance_eval do
      def task_manager
        @task_manager ||= Task::TaskManager.new(self)
      end
    end
  end

  class TaskManager
    attr_reader :hiiro

    def initialize(hiiro)
      @hiiro = hiiro
    end

    def help
      puts "Usage: h task <subcommand> [args]"
      puts
      puts "Subcommands:"
      puts "  list, ls              List all trees and their active tasks"
      puts "  start TASK [TREE]     Start a task (optionally specify tree)"
      puts "  app APP_NAME          Open a tmux window for an app in current tree"
      puts "  apps                  List configured apps from apps.yml"
      puts "  save                  Save current tmux session info for this task"
      puts "  status, st            Show current task status"
      puts "  stop                  Stop working on current task"
    end

    # List all trees (worktree-like dirs) and their active tasks
    def list_trees
      puts "Trees in ~/work/:"
      puts

      trees.each do |tree_name|
        task = task_for_tree(tree_name)
        if task
          puts format("  %-20s => %s", tree_name, task)
        else
          puts format("  %-20s    (available)", tree_name)
        end
      end
    end

    # Start working on a task
    def start_task(task_name, tree: nil)
      tree ||= find_available_tree

      unless tree
        puts "ERROR: No available trees found. All trees have active tasks."
        puts
        list_trees
        return false
      end

      unless trees.include?(tree)
        puts "ERROR: Tree '#{tree}' not found in ~/work/"
        return false
      end

      existing_tree = tree_for_task(task_name)
      if existing_tree
        puts "Task '#{task_name}' already active in tree '#{existing_tree}'"
        puts "Switching to existing session..."
        switch_to_task(task_name, existing_tree)
        return true
      end

      # Associate task with tree
      assign_task_to_tree(task_name, tree)

      # Create/switch to tmux session
      session_name = session_name_for(task_name)
      tree_path = tree_path(tree)

      Dir.chdir(tree_path)
      hiiro.start_tmux_session(session_name)

      save_task_metadata(task_name, tree: tree, session: session_name)

      puts "Started task '#{task_name}' in tree '#{tree}'"
      true
    end

    # Open an app window within the current tree
    def open_app(app_name)
      current = current_task
      unless current
        puts "ERROR: Not currently in a task session"
        puts "Use 'h task start TASK_NAME' first"
        return false
      end

      tree = current[:tree]
      result = find_app_path(tree, app_name)

      case result
      in nil
        puts "ERROR: App '#{app_name}' not found"
        puts
        list_apps(tree)
        return false
      in [:ambiguous, matches]
        puts "ERROR: '#{app_name}' matches multiple apps:"
        matches.each { |m| puts "  #{m}" }
        puts
        puts "Be more specific."
        return false
      in [resolved_name, app_path]
        # Create new tmux window with app directory as base
        system('tmux', 'new-window', '-n', resolved_name, '-c', app_path)
        puts "Opened '#{resolved_name}' in new window (#{app_path})"
        true
      end
    end

    # Save current tmux session state
    def save_current
      current = current_task
      unless current
        puts "ERROR: Not currently in a task session"
        return false
      end

      task_name = current[:task]
      tree = current[:tree]
      session = current[:session]

      # Capture tmux window info
      windows = capture_tmux_windows(session)

      save_task_metadata(task_name,
        tree: tree,
        session: session,
        windows: windows,
        saved_at: Time.now.iso8601
      )

      puts "Saved task '#{task_name}' state (#{windows.count} windows)"
      true
    end

    # Show current task status
    def status
      current = current_task
      unless current
        puts "Not currently in a task session"
        return
      end

      puts "Current task: #{current[:task]}"
      puts "Tree: #{current[:tree]}"
      puts "Session: #{current[:session]}"

      meta = task_metadata(current[:task])
      if meta && meta['saved_at']
        puts "Last saved: #{meta['saved_at']}"
      end
    end

    # Stop working on current task (disassociate from tree)
    def stop_current
      current = current_task
      unless current
        puts "Not currently in a task session"
        return false
      end

      task_name = current[:task]
      tree = current[:tree]

      unassign_task_from_tree(tree)
      puts "Stopped task '#{task_name}' (tree '#{tree}' now available)"
      true
    end

    def list_configured_apps
      if apps_config.any?
        puts "Configured apps (#{apps_config_file}):"
        puts
        apps_config.each do |name, path|
          puts format("  %-20s => %s", name, path)
        end
      else
        puts "No apps configured."
        puts
        puts "Create #{apps_config_file} with format:"
        puts "  app_name: relative/path/from/repo"
        puts
        puts "Example:"
        puts "  partners: partners/partners"
        puts "  admin: admin_portal/admin"
      end
    end

    private

    # Find trees (dirs with .git in ~/work/)
    def trees
      pattern = File.join(Dir.home, 'work', '*', '.git')
      Dir.glob(pattern).map { |git_path|
        File.basename(File.dirname(git_path))
      }.sort
    end

    def tree_path(tree_name)
      File.join(Dir.home, 'work', tree_name)
    end

    # Find an available tree (one without an active task)
    def find_available_tree
      trees.find { |tree| task_for_tree(tree).nil? }
    end

    # Get the task currently assigned to a tree
    def task_for_tree(tree_name)
      assignments[tree_name]
    end

    # Get the tree a task is assigned to
    def tree_for_task(task_name)
      assignments.find { |tree, task| task == task_name }&.first
    end

    # Assign a task to a tree
    def assign_task_to_tree(task_name, tree_name)
      data = assignments
      data[tree_name] = task_name
      save_assignments(data)
    end

    # Unassign task from tree
    def unassign_task_from_tree(tree_name)
      data = assignments
      data.delete(tree_name)
      save_assignments(data)
    end

    # Tree -> Task assignments
    def assignments
      @assignments ||= load_assignments
    end

    def load_assignments
      return {} unless File.exist?(assignments_file)
      YAML.safe_load_file(assignments_file) || {}
    end

    def save_assignments(data)
      FileUtils.mkdir_p(task_dir)
      File.write(assignments_file, YAML.dump(data))
      @assignments = data
    end

    def assignments_file
      File.join(task_dir, 'assignments.yml')
    end

    # Task metadata
    def task_metadata(task_name)
      file = task_metadata_file(task_name)
      return nil unless File.exist?(file)
      YAML.safe_load_file(file)
    end

    def save_task_metadata(task_name, **data)
      FileUtils.mkdir_p(task_dir)
      existing = task_metadata(task_name) || {}
      merged = existing.merge(data.transform_keys(&:to_s))
      File.write(task_metadata_file(task_name), YAML.dump(merged))
    end

    def task_metadata_file(task_name)
      safe_name = task_name.gsub(/[^a-zA-Z0-9_-]/, '_')
      File.join(task_dir, "task_#{safe_name}.yml")
    end

    def task_dir
      File.join(Dir.home, '.config', 'hiiro', 'tasks')
    end

    # Session name for a task
    def session_name_for(task_name)
      "task-#{task_name}"
    end

    # Detect current task from tmux session name
    def current_task
      return nil unless ENV['TMUX']

      session = `tmux display-message -p '#S'`.strip
      return nil unless session.start_with?('task-')

      task_name = session.sub('task-', '')
      tree = tree_for_task(task_name)

      return nil unless tree

      { task: task_name, tree: tree, session: session }
    end

    def switch_to_task(task_name, tree)
      session = session_name_for(task_name)
      tree_path = tree_path(tree)
      Dir.chdir(tree_path)
      hiiro.start_tmux_session(session)
    end

    # Apps config from ~/.config/hiiro/apps.yml
    # Format: { "app_name" => "relative/path/from/repo/root" }
    def apps_config
      @apps_config ||= load_apps_config
    end

    def load_apps_config
      return {} unless File.exist?(apps_config_file)
      YAML.safe_load_file(apps_config_file) || {}
    end

    def apps_config_file
      File.join(Dir.home, '.config', 'hiiro', 'apps.yml')
    end

    # Find app by partial match (must be unique)
    def find_app(partial)
      matches = find_all_apps(partial)

      case matches.count
      when 0
        nil
      when 1
        matches.first
      else
        # Check for exact match among multiple partial matches
        exact = matches.find { |name| name == partial }
        exact ? [exact] : matches
      end
    end

    def find_all_apps(partial)
      apps_config.keys.select { |name| name.start_with?(partial) }
    end

    # App discovery within a tree
    def find_app_path(tree, app_name)
      tree_root = tree_path(tree)

      # First, check apps.yml config
      result = find_app(app_name)

      case result
      when String
        # Single match - use configured path
        return [result, File.join(tree_root, apps_config[result])]
      when Array
        # Multiple matches - return them for error reporting
        return [:ambiguous, result]
      end

      # Fallback: directory discovery if not in config
      # Look for exact match first
      exact = File.join(tree_root, app_name)
      return [app_name, exact] if Dir.exist?(exact)

      # Look for nested app dirs (monorepo pattern: app/app)
      nested = File.join(tree_root, app_name, app_name)
      return [app_name, nested] if Dir.exist?(nested)

      # Fuzzy match on directories
      pattern = File.join(tree_root, '*')
      match = Dir.glob(pattern).find { |path|
        File.basename(path).start_with?(app_name) && File.directory?(path)
      }
      return [File.basename(match), match] if match

      nil
    end

    def list_apps(tree)
      if apps_config.any?
        puts "Configured apps (from apps.yml):"
        apps_config.each do |name, path|
          puts format("  %-20s => %s", name, path)
        end
      else
        puts "No apps configured. Create ~/.config/hiiro/apps.yml"
        puts "Format:"
        puts "  app_name: relative/path/from/repo"
        puts
        puts "Directories in tree:"
        tree_root = tree_path(tree)
        pattern = File.join(tree_root, '*')
        Dir.glob(pattern).select { |p| File.directory?(p) }.each do |path|
          puts "  #{File.basename(path)}"
        end
      end
    end

    # Capture tmux window state
    def capture_tmux_windows(session)
      output = `tmux list-windows -t #{session} -F '\#{window_index}:\#{window_name}:\#{pane_current_path}'`
      output.lines.map(&:strip).map { |line|
        idx, name, path = line.split(':')
        { 'index' => idx, 'name' => name, 'path' => path }
      }
    end
  end
end
