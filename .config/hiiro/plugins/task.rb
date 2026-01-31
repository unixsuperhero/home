#!/usr/bin/env ruby

module Task
  def self.load(hiiro)
    hiiro.load_plugin(Tmux)
    attach_methods(hiiro)
    add_subcommands(hiiro)
  end

  def self.add_subcommands(hiiro)
    hiiro.add_subcmd(:task) do |*args|
      tasks = hiiro.task_manager

      runner_map = {
        edit: ->(*sargs) { system(ENV['EDITOR'] || 'nvim', __FILE__) },
        list: ->(*sargs) { tasks.list_trees },
        ls: ->(*sargs) { tasks.list_trees },
        start: ->(task_name, tree=nil) { tasks.start_task(task_name, tree:) },
        switch: ->(task_name) { tasks.switch_task(task_name) },
        app: ->(*sargs) { tasks.open_app(*sargs) },
        path: ->(app_name=nil, task=nil) { tasks.app_path(app_name, task: task) },
        cd: ->(*sargs) { tasks.cd_app(*sargs) },
        apps: ->(*sargs) { tasks.list_configured_apps },
        status: ->(*sargs) { tasks.status },
        save: ->(*sargs) { tasks.save_current },
        stop: ->(*sargs) { tasks.stop_current },
        subtask: ->(*sargs) { tasks.handle_subtask(*sargs) },
      }

      case args
      in []
        tasks.help
      in ['edit']
        runner_map[:edit].call
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
      in ['stop', task_name]
        tasks.stop_task(task_name)
      in ['subtask']
        tasks.subtask_help
      in ['subtask', 'ls']
        tasks.list_subtasks
      in ['subtask', 'new', subtask_name]
        tasks.new_subtask(subtask_name)
      in ['subtask', 'switch', subtask_name]
        tasks.switch_subtask(subtask_name)
      in [subcmd, *sargs]
        match = runner_map.keys.find { |full_subcmd| full_subcmd.to_s.start_with?(subcmd) }

        if match
          runner_map[match].call(*sargs)
        else
          puts "Unknown task subcommand: #{args.inspect}"
          tasks.help
        end
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
      puts "  list, ls              List all worktrees and their active tasks"
      puts "  start TASK            Start a task (reuses available worktree or creates new)"
      puts "  switch TASK           Switch to an existing task"
      puts "  app APP_NAME          Open a tmux window for an app in current worktree"
      puts "  apps                  List configured apps from apps.yml"
      puts "  save                  Save current tmux session info for this task"
      puts "  status, st            Show current task status"
      puts "  stop                  Stop working on current task (worktree becomes available)"
      puts "  subtask <subcmd>      Manage subtasks (ls, new, switch)"
    end

    # List all worktrees and their active tasks
    def list_trees
      puts "Git worktrees:"
      puts

      if trees.empty?
        puts "  (no worktrees found)"
        puts
        puts "  Start a task with 'h task start TASK_NAME' to create one."
        return
      end

      current = current_task
      active, available = trees.partition { |tree_name| task_for_tree(tree_name) }

      active.each do |tree_name|
        task = task_for_tree(tree_name)
        marker = (current && current[:tree] == tree_name) ? "*" : " "
        puts format("%s %-20s => %s", marker, tree_name, task)
      end

      puts if active.any? && available.any?

      available.each do |tree_name|
        puts format("  %-20s    (available)", tree_name)
      end
    end

    # Start working on a task
    def start_task(task_name, tree: nil)
      # Check if task already exists as a worktree
      existing_tree = tree_for_task(task_name)
      if existing_tree
        puts "Task '#{task_name}' already active in tree '#{existing_tree}'"
        puts "Switching to existing session..."
        switch_to_task(task_name, existing_tree)
        return true
      end

      # If a specific tree was requested, verify it exists and isn't reserved
      if tree
        if !trees.include?(tree)
          puts "ERROR: Worktree '#{tree}' not found"
          return false
        end
        if RESERVED_WORKTREES.key?(tree)
          puts "ERROR: Worktree '#{tree}' is reserved and cannot be used for tasks"
          return false
        end
      end

      # Find an available worktree to reuse, or create a new one
      available_tree = tree || find_available_tree

      if available_tree
        # Rename the available worktree to the task name
        old_path = tree_path(available_tree)
        new_path = File.join(File.dirname(old_path), task_name)

        if available_tree != task_name
          puts "Renaming worktree '#{available_tree}' to '#{task_name}'..."
          result = system('git', '-C', main_repo_path, 'worktree', 'move', old_path, new_path)
          unless result
            puts "ERROR: Failed to rename worktree"
            return false
          end
          clear_worktree_cache
        end

        final_tree_name = task_name
        final_tree_path = new_path
      else
        # No available worktree, create a new one
        puts "Creating new worktree for '#{task_name}'..."
        new_path = File.join(Dir.home, 'work', task_name)

        # Create worktree from main branch (detached to avoid branch conflicts)
        result = system('git', '-C', main_repo_path, 'worktree', 'add', '--detach', new_path)
        unless result
          puts "ERROR: Failed to create worktree"
          return false
        end
        clear_worktree_cache

        final_tree_name = task_name
        final_tree_path = new_path
      end

      # Associate task with tree
      assign_task_to_tree(task_name, final_tree_name)

      # Create/switch to tmux session
      session_name = session_name_for(task_name)

      Dir.chdir(final_tree_path)
      hiiro.start_tmux_session(session_name)

      save_task_metadata(task_name, tree: final_tree_name, session: session_name)

      puts "Started task '#{task_name}' in worktree '#{final_tree_name}'"
      true
    end

    # Start working on a task
    def switch_task(task_name)
      tree, task = assignments.find { |tree, task| task.start_with?(task_name) } || []

      unless task
        puts "No task matching #{task_name} found."
        return false
      end

      switch_to_task(task, tree)

      puts "Started task '#{task}' in tree '#{tree}'"
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

    # Open an app window within the current tree
    def cd_app(app_name=nil)
      current = current_task
      unless current
        puts "ERROR: Not currently in a task session"
        puts "Use 'h task start TASK_NAME' first"
        return false
      end

      tree = current[:tree]

      result = []
      if app_name.to_s == ''
        result = ['root', tree_path(tree)]
      else
        result = find_app_path(tree, app_name)
      end

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
        pane = ENV['TMUX_PANE']
        if pane
          puts "PANE: #{pane}"
          puts command: ['tmux', 'send-keys', '-t', pane, "cd #{app_path}\n"].join(' ')
          system('tmux', 'send-keys', '-t', pane, "cd #{app_path}\n")
        else
          puts command: ['tmux', 'send-keys', "cd #{app_path}\n"].join(' ')
          system('tmux', 'send-keys', "cd #{app_path}\n")
        end
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
      puts "Worktree: #{current[:tree]}"
      puts "Path: #{tree_path(current[:tree])}"
      puts "Session: #{current[:session]}"

      meta = task_metadata(current[:task])
      if meta && meta['saved_at']
        puts "Last saved: #{meta['saved_at']}"
      end
    end

    # Stop working on current task (disassociate from worktree)
    def stop_current
      current = current_task
      unless current
        puts "Not currently in a task session"
        return false
      end

      stop_task(current[:task])
    end

    # Stop working on a task (disassociate from worktree)
    def stop_task(task_name)
      tree = tree_for_task(task_name)
      task_name = task_for_tree(tree)

      if RESERVED_WORKTREES.key?(tree)
        puts "Cannot stop reserved task '#{task_name}'"
        return false
      end

      unassign_task_from_tree(tree)
      puts "Stopped task '#{task_name}' (worktree '#{tree}' now available for reuse)"
      true
    end

    # Subtask management
    def subtask_help
      puts "Usage: h task subtask <subcommand> [args]"
      puts "       h subtask <subcommand> [args]"
      puts
      puts "Subcommands:"
      puts "  ls                    List subtasks for current task"
      puts "  new SUBTASK_NAME      Start a new subtask (creates worktree and session)"
      puts "  switch SUBTASK_NAME   Switch to subtask's tmux session"
    end

    def handle_subtask(*args)
      case args
      in []
        subtask_help
      in ['ls']
        list_subtasks
      in ['new', subtask_name]
        new_subtask(subtask_name)
      in ['switch', subtask_name]
        switch_subtask(subtask_name)
      else
        puts "Unknown subtask command: #{args.inspect}"
        subtask_help
      end
    end

    def list_subtasks
      current = current_task
      unless current
        puts "ERROR: Not currently in a task session"
        return false
      end

      parent_task = current[:task]
      subtasks = subtasks_for_task(parent_task)

      if subtasks.empty?
        puts "No subtasks for task '#{parent_task}'."
        puts
        puts "Create one with 'h subtask new SUBTASK_NAME'"
        return
      end

      puts "Subtasks for '#{parent_task}':"
      puts
      subtasks.each do |subtask|
        marker = subtask['active'] ? "*" : " "
        puts format("%s %-25s  tree: %-15s  created: %s",
          marker,
          subtask['name'],
          subtask['worktree'] || '(none)',
          subtask['created_at']&.split('T')&.first || '?'
        )
      end
    end

    def new_subtask(subtask_name)
      current = current_task
      unless current
        puts "ERROR: Not currently in a task session"
        puts "Use 'h task start TASK_NAME' first"
        return false
      end

      parent_task = current[:task]
      full_subtask_name = "#{parent_task}/#{subtask_name}"

      # Check if subtask already exists
      existing = subtasks_for_task(parent_task).find { |s| s['name'] == subtask_name }
      if existing
        puts "Subtask '#{subtask_name}' already exists for task '#{parent_task}'"
        puts "Switching to existing session..."
        switch_subtask(subtask_name)
        return true
      end

      # Create new worktree for subtask
      puts "Creating new worktree for subtask '#{subtask_name}'..."
      new_path = File.join(Dir.home, 'work', full_subtask_name)

      result = system('git', '-C', main_repo_path, 'worktree', 'add', '--detach', new_path)
      unless result
        puts "ERROR: Failed to create worktree"
        return false
      end
      clear_worktree_cache

      # Associate subtask with tree
      assign_task_to_tree(full_subtask_name, full_subtask_name)

      # Record subtask in parent's metadata
      add_subtask_to_task(parent_task, {
        'name' => subtask_name,
        'worktree' => full_subtask_name,
        'session' => full_subtask_name,
        'created_at' => Time.now.iso8601,
        'active' => true
      })

      # Create/switch to tmux session
      Dir.chdir(new_path)
      hiiro.start_tmux_session(full_subtask_name)

      puts "Started subtask '#{subtask_name}' for task '#{parent_task}'"
      true
    end

    def switch_subtask(subtask_name)
      current = current_task
      unless current
        puts "ERROR: Not currently in a task session"
        puts "Use 'h task start TASK_NAME' first"
        return false
      end

      parent_task = current[:task]
      # Handle if we're in a subtask - get the parent
      if parent_task.include?('/')
        parent_task = parent_task.split('/').first
      end

      subtask = find_subtask(parent_task, subtask_name)
      unless subtask
        puts "Subtask '#{subtask_name}' not found for task '#{parent_task}'"
        puts
        list_subtasks
        return false
      end

      session_name = subtask['session'] || "#{parent_task}/#{subtask_name}"
      tree_name = subtask['worktree'] || session_name

      # Check if session exists
      session_exists = system('tmux', 'has-session', '-t', session_name, err: File::NULL)

      if session_exists
        hiiro.start_tmux_session(session_name)
      else
        # Create new session in the worktree path
        path = tree_path(tree_name)
        if Dir.exist?(path)
          Dir.chdir(path)
          hiiro.start_tmux_session(session_name)
        else
          puts "ERROR: Worktree path '#{path}' does not exist"
          return false
        end
      end

      puts "Switched to subtask '#{subtask_name}'"
      true
    end

    private

    def subtasks_for_task(task_name)
      meta = task_metadata(task_name)
      return [] unless meta
      meta['subtasks'] || []
    end

    def find_subtask(parent_task, subtask_name)
      subtasks = subtasks_for_task(parent_task)
      subtasks.find { |s| s['name'].start_with?(subtask_name) }
    end

    def add_subtask_to_task(parent_task, subtask_data)
      meta = task_metadata(parent_task) || {}
      meta['subtasks'] ||= []
      meta['subtasks'] << subtask_data
      FileUtils.mkdir_p(task_dir)
      File.write(task_metadata_file(parent_task), YAML.dump(meta))
    end

    public

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

    def app_path(app_name, task: nil)
      tree_root = task ? tree_path(tree_for_task(task)) : `git rev-parse --show-toplevel`.strip

      if app_name.nil?
        print tree_root
        exit 0
      end

      matching_apps = find_all_apps(app_name)
      longest_app_name = printable_apps.keys.max_by(&:length).length + 2

      case matching_apps.count
      when 0
        puts "ERROR: No matches found"
        puts
        puts "Possible Apps:"
        puts printable_apps.keys.sort.map{|k| format("%#{longest_app_name}s => %s", k, printable_apps[k]) }
        exit 1
      when 1
        print File.join(tree_root, apps_config[matching_apps.first])
        exit 0
      else
        puts "Multiple matches found:"
        puts matching_apps.sort.map{|k| format("%#{longest_app_name}s => %s", k, printable_apps[k]) }
        exit 1
      end
    end

    private

    def printable_apps
      apps_config.transform_keys(&:to_s)
    end

    # Find worktrees using git worktree list
    def trees
      worktree_info.keys.sort
    end

    # Parse git worktree list output into { name => path } hash
    def worktree_info
      @worktree_info ||= begin
        output = `git -C #{main_repo_path} worktree list --porcelain 2>/dev/null`
        info = {}
        current_path = nil

        output.lines.each do |line|
          line = line.strip
          if line.start_with?('worktree ')
            current_path = line.sub('worktree ', '')
          elsif line == 'bare'
            # Skip bare repo
            current_path = nil
          elsif line.start_with?('branch ') || line == 'detached'
            # Capture worktree (both named branches and detached HEAD)
            if current_path && current_path != main_repo_path
              name = File.basename(current_path)
              info[name] = current_path
            end
            current_path = nil
          end
        end

        info
      end
    end

    def clear_worktree_cache
      @worktree_info = nil
    end

    # Get the main repo path (where we run git worktree commands from)
    def main_repo_path
      File.join(Dir.home, 'work', '.bare')
    end

    def tree_path(tree_name)
      worktree_info[tree_name] || File.join(Dir.home, 'work', tree_name)
    end

    # Worktrees with permanent task assignments (worktree => task)
    RESERVED_WORKTREES = { 'carrot' => 'master' }.freeze

    # Find an available tree (one without an active task)
    def find_available_tree
      trees.find { |tree| task_for_tree(tree).nil? && !RESERVED_WORKTREES.key?(tree) }
    end

    # Get the task currently assigned to a tree
    def task_for_tree(tree_name)
      assignments[tree_name]
    end

    # Get the tree a task is assigned to
    def tree_for_task(task_name)
      assignment_for_task(task_name)&.first
    end

    def assignment_for_task(partial)
      assignments.find { |tree, task| task.start_with?(partial) }
    end

    def find_task(partial)
      assignments.values.find { |task| task.start_with?(partial) }
    end

    # Assign a task to a tree
    def assign_task_to_tree(task_name, tree_name)
      data = assignments
      data[tree_name] = task_name
      save_assignments(data)
    end

    # Unassign task from tree
    def unassign_task_from_tree(tree_name)
      return if RESERVED_WORKTREES.key?(tree_name)
      data = assignments.dup
      data.delete(tree_name)
      save_assignments(data)
    end

    # Tree -> Task assignments
    def assignments
      @assignments ||= load_assignments
    end

    def load_assignments
      data = if File.exist?(assignments_file)
        YAML.safe_load_file(assignments_file) || {}
      else
        {}
      end
      # Always include reserved worktree assignments
      RESERVED_WORKTREES.merge(data)
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
      task_name
    end

    # Detect current task from tmux session name
    def current_task
      return nil unless ENV['TMUX']

      session = `tmux display-message -p '#S'`.strip

      task_name = session
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
