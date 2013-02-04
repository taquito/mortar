#
# Copyright 2012 Mortar Data Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Mortar
  module Snapshot

    extend self
    
    def create_and_push_snapshot_branch(git, project)
      curdir = Dir.pwd

      # create a snapshot branch in a temporary directory
      tmpdir, snapshot_branch = action("Taking code snapshot") do
        git.create_snapshot_branch()
      end

      Dir.chdir(tmpdir)

      git_ref = action("Sending code snapshot to Mortar") do
        # push the code
        git.push(project.remote, snapshot_branch)

        # grab the commit hash and clean out the branch from the local branches
        ref = git.git_ref(snapshot_branch)
        git.branch_delete(snapshot_branch)
        ref
      end

      Dir.chdir(curdir)
      FileUtils.remove_entry_secure(tmpdir)
      return git_ref
    end
  end
end