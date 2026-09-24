# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "tmpdir"

RSpec.describe "script/backport.rb" do
  let(:directory) { Dir.mktmpdir("backport") }
  let(:source) { File.join(directory, "source") }
  let(:remote) { File.join(directory, "remote.git") }
  let(:work) { File.join(directory, "work") }
  let(:outputs) { File.join(directory, "outputs") }
  let(:summary) { File.join(directory, "summary") }
  let(:environment) do
    {
      "GIT_AUTHOR_NAME" => "Test",
      "GIT_AUTHOR_EMAIL" => "test@example.com",
      "GIT_COMMITTER_NAME" => "Test",
      "GIT_COMMITTER_EMAIL" => "test@example.com",
      "GIT_CONFIG_GLOBAL" => "/dev/null",
      "GIT_CONFIG_NOSYSTEM" => "1",
      "PATH" => "#{directory}:#{ENV.fetch("PATH")}",
      "PR_NUMBER" => "123",
      "COMMENT_BODY" => "@discoursebot backport",
      "GITHUB_OUTPUT" => outputs,
      "SUMMARY" => summary,
    }
  end

  after { FileUtils.remove_entry(directory) }

  def git(path, *arguments)
    stdout, stderr, status = Open3.capture3(environment, "git", *arguments, chdir: path)
    raise stderr unless status.success?
    stdout.strip
  end

  def run_backport(conflict: false, reject_push: false)
    git(directory, "init", "--bare", remote)
    git(directory, "init", "-b", "main", source)
    File.write(File.join(source, "file"), "original\n")
    File.write(
      File.join(source, "versions.json"),
      {
        "2026.5" => {
          supported: true,
          released: true,
        },
        "2026.4" => {
          supported: true,
          released: true,
        },
      }.to_json,
    )
    git(source, "add", ".")
    git(source, "commit", "-m", "Initial")
    git(source, "branch", "release/2026.4")
    git(source, "checkout", "-b", "release/2026.5")
    if conflict
      File.write(File.join(source, "file"), "release-specific change\n")
      git(source, "commit", "-am", "Release change")
    end
    git(source, "checkout", "main")
    File.write(File.join(source, "file"), "upstream fix\n")
    git(source, "commit", "-am", "Fix")
    environment["MERGE_COMMIT"] = git(source, "rev-parse", "HEAD")
    git(source, "push", remote, "--all")
    git(source, "push", remote, "HEAD:refs/pull/123/head")
    git(directory, "clone", "-b", "main", remote, work)
    if reject_push
      hook = File.join(remote, "hooks/pre-receive")
      File.write(hook, "#!/bin/sh\nexit 1\n")
      FileUtils.chmod(0o755, hook)
    end

    File.write(File.join(directory, "gh"), <<~'RUBY')
      #!/usr/bin/env ruby
      require "json"
      case ARGV.first
      when "repo"
        puts "test/repo"
      when "pr"
        if ARGV[1] == "view" && ARGV[2] == "123"
          puts({ title: "Fix", body: "Original PR", baseRefName: "main", mergeCommit: { oid: ENV.fetch("MERGE_COMMIT") } }.to_json)
        elsif ARGV[1] == "view"
          puts "https://github.com/test/repo/pull/456"
        end
      when "api"
        File.write(ENV.fetch("SUMMARY"), ARGV.find { |arg| arg.start_with?("body=") }.delete_prefix("body="))
        puts "https://github.com/test/repo/pull/123#issuecomment-789"
      else
        abort "Unexpected gh invocation: #{ARGV.inspect}"
      end
    RUBY
    FileUtils.chmod(0o755, File.join(directory, "gh"))
    stdout, stderr, status =
      Open3.capture3(
        environment,
        "ruby",
        File.expand_path("../../script/backport.rb", __dir__),
        chdir: work,
      )
    expect(status.success?).to eq(true), "#{stdout}\n#{stderr}"
    File.read(outputs).lines.to_h { |line| line.strip.split("=", 2) }
  end

  it "reports only conflicted targets and preserves the manual failure instructions" do
    result = run_backport(conflict: true)

    expect(result).to eq(
      "conflicts" => "true",
      "conflict_versions" => "2026.5",
      "result_url" => "https://github.com/test/repo/pull/123#issuecomment-789",
    )
    expect(File.read(summary)).to include(
      "Successful backports",
      "Failed backports",
      "To resolve manually:",
    )
    expect(git(remote, "show", "backport/2026.4/123:file")).to eq("upstream fix")
  end

  it "leaves successful backports to the existing automation" do
    expect(run_backport).to include("conflicts" => "false", "conflict_versions" => "")
    expect(git(remote, "show", "backport/2026.5/123:file")).to eq("upstream fix")
  end

  it "reports push failures without requesting AI conflict resolution" do
    expect(run_backport(reject_push: true)).to include(
      "conflicts" => "false",
      "conflict_versions" => "",
    )
    expect(File.read(summary)).to include("Failed backports", "pre-receive hook declined")
  end
end
