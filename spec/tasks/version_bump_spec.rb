# frozen_string_literal: true

def run(*args)
  out, err, status = Open3.capture3(*args)
  raise "Command failed: #{args.inspect}\n#{out}\n#{err}" unless status.success?
  out
end

def fake_version_rb(version)
  File.read("#{Rails.root}/lib/version.rb").sub(/STRING = ".*"/, "STRING = \"#{version}\"")
end

RSpec.describe "tasks/version_bump" do
  let(:tmpdir) { Dir.mktmpdir }
  let(:origin_path) { "#{tmpdir}/origin-repo" }
  let(:local_path) { "#{tmpdir}/local-repo" }

  before do
    ENV["RUNNING_VERSION_BUMP_IN_RSPEC_TESTS"] = "1"

    Rake::Task.clear
    Discourse::Application.load_tasks

    FileUtils.mkdir_p origin_path

    Dir.chdir(origin_path) do
      FileUtils.mkdir_p "lib"
      FileUtils.mkdir_p "tmp"

      File.write(".gitignore", "tmp\n")
      File.write("lib/version.rb", fake_version_rb("3.2.0.beta1-latest"))

      run "git", "init"
      run "git", "checkout", "-b", "main"
      run "git", "add", "."
      run "git", "commit", "-m", "Initial commit"

      run "git", "checkout", "-b", "stable"
      File.write("#{origin_path}/lib/version.rb", fake_version_rb("3.1.2"))
      run "git", "add", "."
      run "git", "commit", "-m", "Previous stable version bump"

      run "git", "checkout", "main"
      run "git", "config", "receive.denyCurrentBranch", "ignore"
    end

    run "git", "clone", "-b", "main", origin_path, local_path
  end

  after do
    FileUtils.remove_entry(tmpdir)
    ENV.delete("RUNNING_VERSION_BUMP_IN_RSPEC_TESTS")
  end

  it "can bump the beta version with version_bump:beta" do
    Dir.chdir(local_path) { capture_stdout { invoke_rake_task("version_bump:beta") } }

    Dir.chdir(origin_path) do
      # Commits are present with correct messages
      expect(run("git", "log", "--pretty=%s").lines.map(&:strip)).to eq(
        ["Bump version to v3.2.0.beta2-latest", "Bump version to v3.2.0.beta1", "Initial commit"],
      )

      # Expected tags present
      expect(run("git", "tag").lines.map(&:strip)).to contain_exactly(
        "latest-release",
        "beta",
        "v3.2.0.beta1",
      )

      # Tags are all present and attached to the correct commit
      %w[latest-release beta v3.2.0.beta1].each do |tag_name|
        expect(run("git", "log", "--pretty=%s", "-1", tag_name).strip).to eq(
          "Bump version to v3.2.0.beta1",
        )
      end

      # Version numbers in version.rb are correct at all commits
      expect(run "git", "show", "HEAD", "lib/version.rb").to include(
        'STRING = "3.2.0.beta2-latest"',
      )
      expect(run "git", "show", "HEAD~1", "lib/version.rb").to include('STRING = "3.2.0.beta1"')
      expect(run "git", "show", "HEAD~2", "lib/version.rb").to include(
        'STRING = "3.2.0.beta1-latest"',
      )
    end
  end

  it "can perform a minor stable bump with version_bump:minor_stable" do
    Dir.chdir(local_path) { capture_stdout { invoke_rake_task("version_bump:minor_stable") } }

    Dir.chdir(origin_path) do
      # No commits on main branch
      expect(run("git", "log", "--pretty=%s").lines.map(&:strip)).to eq(["Initial commit"])

      # Expected tags present
      expect(run("git", "tag").lines.map(&:strip)).to eq(["v3.1.3"])

      run "git", "checkout", "stable"

      # Correct commits on stable branch
      expect(run("git", "log", "--pretty=%s").lines.map(&:strip)).to eq(
        ["Bump version to v3.1.3", "Previous stable version bump", "Initial commit"],
      )

      # Tag points to correct commit
      expect(run("git", "log", "--pretty=%s", "-1", "v3.1.3").strip).to eq("Bump version to v3.1.3")

      # Version numbers in version.rb are correct at all commits
      expect(run "git", "show", "HEAD", "lib/version.rb").to include('STRING = "3.1.3"')
      expect(run "git", "show", "HEAD~1", "lib/version.rb").to include('STRING = "3.1.2"')
    end
  end

  it "can prepare a major stable bump with version_bump:major_stable_prepare" do
    Dir.chdir(local_path) do
      capture_stdout { invoke_rake_task("version_bump:major_stable_prepare", "3.3.0") }
    end

    Dir.chdir(origin_path) do
      # Commits are present with correct messages
      expect(run("git", "log", "--pretty=%s").lines.map(&:strip)).to eq(
        ["Bump version to v3.3.0.beta1-latest", "Bump version to v3.2.0.beta1", "Initial commit"],
      )

      # Expected tags present
      expect(run("git", "tag").lines.map(&:strip)).to contain_exactly(
        "latest-release",
        "beta",
        "v3.2.0.beta1",
      )

      # Tags are all present and attached to the correct commit
      %w[latest-release beta v3.2.0.beta1].each do |tag_name|
        expect(run("git", "log", "--pretty=%s", "-1", tag_name).strip).to eq(
          "Bump version to v3.2.0.beta1",
        )
      end

      # Version numbers in version.rb are correct at all commits
      expect(run "git", "show", "HEAD:lib/version.rb").to include('STRING = "3.3.0.beta1-latest"')
      expect(run "git", "show", "HEAD~1:lib/version.rb").to include('STRING = "3.2.0.beta1"')
      expect(run "git", "show", "HEAD~2:lib/version.rb").to include('STRING = "3.2.0.beta1-latest"')

      # No changes to stable branch
      expect(run("git", "log", "--pretty=%s", "stable").lines.map(&:strip)).to eq(
        ["Previous stable version bump", "Initial commit"],
      )
    end
  end

  it "can merge a stable release commit into the stable branch with version_bump:major_stable_merge" do
    Dir.chdir(local_path) do
      # Prepare first, and find sha1 in output
      output = capture_stdout { invoke_rake_task("version_bump:major_stable_prepare", "3.3.0") }
      stable_bump_commit = output[/major_stable_merge\[(.*)\]/, 1]
      capture_stdout { invoke_rake_task("version_bump:major_stable_merge", stable_bump_commit) }
    end

    Dir.chdir(origin_path) do
      # Commits on stable branch are present with correct messages
      expect(run("git", "log", "--pretty=%s", "stable").lines.map(&:strip)).to contain_exactly(
        "Merge v3.2.0.beta1 into stable",
        "Bump version to v3.2.0",
        "Previous stable version bump",
        "Bump version to v3.2.0.beta1",
        "Initial commit",
      )

      # Most recent commit is the version bump
      expect(run("git", "log", "--pretty=%s", "-1", "stable").strip).to eq("Bump version to v3.2.0")

      # Second most recent commit is a merge commit
      parents = run("git", "log", "--pretty=%P", "-n", "1", "stable~1").split(/\s+/).map(&:strip)
      expect(parents.length).to eq(2)

      # With correct parents
      parent_commit_messages = parents.map { |p| run("git", "log", "--pretty=%s", "-1", p).strip }
      expect(parent_commit_messages).to contain_exactly(
        "Bump version to v3.2.0.beta1",
        "Previous stable version bump",
      )

      # Tag is applied to stable version bump commit
      expect(run("git", "log", "--pretty=%s", "-1", "v3.2.0").strip).to eq("Bump version to v3.2.0")
    end
  end

  it "can stage a PR of multiple security fixes using version_bump:stage_security_fixes" do
    Dir.chdir(origin_path) do
      run "git", "checkout", "-b", "security-fix-one"

      File.write("firstfile.txt", "contents")
      run "git", "add", "firstfile.txt"
      run "git", "commit", "-m", "security fix one, commit one"
      File.write("secondfile.txt", "contents")
      run "git", "add", "secondfile.txt"
      run "git", "commit", "-m", "security fix one, commit two"

      run "git", "checkout", "main"
      run "git", "checkout", "-b", "security-fix-two"
      File.write("somefile.txt", "contents")
      run "git", "add", "somefile.txt"
      run "git", "commit", "-m", "security fix two"
    end

    Dir.chdir(local_path) do
      output =
        capture_stdout do
          ENV["SECURITY_FIX_REFS"] = "origin/security-fix-one,origin/security-fix-two"
          invoke_rake_task("version_bump:stage_security_fixes", "main")
        ensure
          ENV.delete("SECURITY_FIX_REFS")
        end
    end

    Dir.chdir(origin_path) do
      # Check each fix has been added as a single commit, with the message matching the first commit on the branch
      expect(run("git", "log", "--pretty=%s", "main").lines.map(&:strip)).to eq(
        [
          "security fix two",
          "security fix one, commit two",
          "security fix one, commit one",
          "Initial commit",
        ],
      )

      # Check all the files from both fixes are present
      expect(run("git", "show", "main:somefile.txt")).to eq("contents")
      expect(run("git", "show", "main:firstfile.txt")).to eq("contents")
      expect(run("git", "show", "main:secondfile.txt")).to eq("contents")
    end
  end

  describe "version_bump:maybe_tag_release" do
    it "does not tag if commit is not on a release/* branch" do
      Dir.chdir(local_path) do
        File.write("lib/version.rb", fake_version_rb("2025.06.0"))
        run "git", "add", "."
        run "git", "commit", "-m", "release 2025.06.0"
        commit_hash = run("git", "rev-parse", "HEAD").strip
        # Not on a release/* branch, should not tag
        capture_stdout { invoke_rake_task("version_bump:maybe_tag_release", commit_hash) }
        # Should not tag, so v2025.06.0 should not exist
        expect(run("git", "tag").lines.map(&:strip)).not_to include("v2025.06.0")
      end
    end
    it "tags a release if not a prerelease and tag does not exist" do
      Dir.chdir(local_path) do
        File.write("lib/version.rb", fake_version_rb("2025.03.0"))
        run "git", "add", "."
        run "git", "commit", "-m", "release 2025.03.0"
        commit_hash = run("git", "rev-parse", "HEAD").strip
        run "git", "branch", "release/2025.03"
        output = capture_stdout { invoke_rake_task("version_bump:maybe_tag_release", commit_hash) }
        expect(output).to include("Tagging release v2025.03.0")
        expect(run("git", "tag").lines.map(&:strip)).to include("v2025.03.0")
      end
    end

    it "skips tagging if version is a prerelease" do
      Dir.chdir(local_path) do
        File.write("lib/version.rb", fake_version_rb("2025.04.0-latest"))
        run "git", "add", "."
        run "git", "commit", "-m", "release 2025.04.0-latest"
        commit_hash = run("git", "rev-parse", "HEAD").strip
        run "git", "branch", "release/2025.04"
        output = capture_stdout { invoke_rake_task("version_bump:maybe_tag_release", commit_hash) }
        expect(output).to include("is a prerelease. Skipping")
        expect(run("git", "tag").lines.map(&:strip)).not_to include("v2025.04.0-latest")
      end
    end

    it "skips tagging if tag already exists" do
      Dir.chdir(local_path) do
        File.write("lib/version.rb", fake_version_rb("2025.05.0"))
        run "git", "add", "."
        run "git", "commit", "-m", "release 2025.05.0"
        commit_hash = run("git", "rev-parse", "HEAD").strip
        run "git", "branch", "release/2025.05"
        # Create tag manually
        run "git", "tag", "-a", "v2025.05.0", "-m", "version 2025.05.0"
        output = capture_stdout { invoke_rake_task("version_bump:maybe_tag_release", commit_hash) }
        expect(output).to include("Tag v2025.05.0 already exists, skipping")
      end
    end
  end

  it "can create a new release branch" do
    latest_hash, previous_hash = nil

    Dir.chdir(local_path) do
      File.write("lib/version.rb", fake_version_rb("2025.01.0-latest"))
      run "git", "add", "."
      run "git", "commit", "-m", "developing 2025.01"

      previous_hash = run("git", "rev-parse", "HEAD").strip

      File.write("lib/version.rb", fake_version_rb("2025.02.0-latest"))
      run "git", "add", "."
      run "git", "commit", "-m", "begin development of 2025.02-latest"

      latest_hash = run("git", "rev-parse", "HEAD").strip

      output = capture_stdout { invoke_rake_task("version_bump:maybe_cut_branch", latest_hash) }
      expect(output).to include("Created new branch")
    end

    Dir.chdir(origin_path) do
      run "git", "checkout", "release/2025.01"
      branch_tip = run("git", "rev-parse", "HEAD").strip
      expect(branch_tip).to eq(previous_hash)
    end
  end
end
