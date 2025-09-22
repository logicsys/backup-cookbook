#
# Cookbook:: backup
# Attributes:: default
#
# Copyright:: 2011, Cramer Development, Inc.
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

default['backup']['path']         = '/var/backups' # LEGACY
default['backup']['config_path']  = '/etc/backup'
default['backup']['log_path']     = '/var/log'
default['backup']['addl_flags']   = ''
default['backup']['model_path']   = "#{node['backup']['config_path']}/models"
default['backup']['mount_options'] = []

default['backup']['user']         = 'root'
default['backup']['group']        = 'root'

default['backup']['dependencies'] = []
default['backup']['version'] = '5.0.0'
default['backup']['version_from_git?'] = false
default['backup']['git_repo'] = nil
default['backup']['git_repo_revision'] = 'master'
default['backup']['upgrade?'] = false

default['backup']['server'] = {}

default['backup']['use_rvm'] = false
default['backup']['rvm_ruby_string'] = 'default'

# Platform-specific defaults for RHEL 9+
case node['platform_family']
when 'rhel', 'fedora'
  if node['platform_version'].to_f.to_i >= 9
    default['backup']['use_rvm'] = true
    default['backup']['rvm_ruby_string'] = 'ruby-3.3.9'
    default['backup']['version'] = '5.0.0'
	
	default['backup']['version_from_git?'] = true
	default['backup']['git_repo'] = "https://github.com/logicsys/backup"
	# default['backup']['git_repo'] = "https://gitlab.yakara.com/yakara-platform/backup_gem.git"
	default['backup']['git_repo_revision'] = 'yakara'
  end

  if node['platform_version'].to_f.to_i >= 10
  	default['backup']['rvm_ruby_string'] = 'ruby-3.4.6'
  end

end

