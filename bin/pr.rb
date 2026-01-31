class Pr
  attr_reader :data

  def self.fetch
    json = `gh pr status --json number,author,headRefName,isDraft,mergeStateStatus,mergeable,reviewDecision,state,title,url,comments --jq '.createdBy'`

    prs_from_json(json)
  end

  def self.fetch_all
    json = `gh pr status --json number,author,headRefName,isDraft,mergeStateStatus,mergeable,reviewDecision,state,title,url,comments`

    result = JSON.parse(json)

    prs = (result["createdBy"] + result["needsReview"]) << result["currentBranch"]
    prs.map { |pr| new(pr) }
  rescue
    :failed
  end

  def self.prs_from_json(json)
    JSON.parse(json).each_with_object({}) do |pr, h|
      o = new(pr)

      h[o.number] = o
    end
  rescue => e
    puts failed: e.message
    :failed
  end

  def initialize(data)
    @data = data
  end

  def author = data.dig(*%w[author login])
  def branch = data["headRefName"]
  def number = data["number"]

  def is_draft = data["isDraft"]
  def merge_state_status = data["mergeStateStatus"]
  def mergeable = data["mergeable"]
  def review_decision = data["reviewDecision"]
  def state = data["state"]
  def title = data["title"]
  def url = data["url"]
  def comments = data["comments"]
  def comment_count = comments.count

  def to_h
    {
      number:,
      branch:,
      author:,
      is_draft:,
      merge_state_status:,
      mergeable:,
      review_decision:,
      state:,
      title:,
      url:,
      comment_count:,
    }
  end

  def ready_for_review?
    is_draft && mergeable == "MERGEABLE" && merge_state_status == "BLOCKED"
  end

  def diff(old_pr)
    new_values = to_h
    old_values = old_pr.to_h

    return {} if old_values.empty?

    diff = new_values.each_with_object({}) do |(k, v), h|
      next if old_values[k] == v

      h[k] = [old_values[k], v]
    end
  end
end
