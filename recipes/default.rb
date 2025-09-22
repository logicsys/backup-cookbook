#
# Cookbook:: backup
# Recipe:: default
#
# Copyright:: 2011-2012, Cramer Development, Inc.
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

if node['backup']['use_rvm']
  ruby_string = node['backup']['rvm_ruby_string'] || 'ruby-3.1.0'

  # Install development packages required for building Ruby
  case node['platform_family']
  when 'rhel', 'fedora'
    # Install EPEL repository first
    package 'epel-release' do
      action :install
    end

    # Enable CodeReady/PowerTools/CRB repository for RHEL 8+
    if node['platform_version'].to_i >= 8
      case node['platform']
      when 'redhat', 'centos'
        if node['platform_version'].to_i == 8
          # RHEL 8 / CentOS 8 uses PowerTools or CodeReady
          execute 'enable-codeready-repo' do
            command 'dnf config-manager --set-enabled powertools || dnf config-manager --set-enabled codeready-builder-for-rhel-8-x86_64-rpms'
            action :run
            not_if 'dnf repolist enabled | grep -E "powertools|codeready"'
          end
        elsif node['platform_version'].to_i >= 9
          # RHEL 9+ uses CRB
          execute 'enable-crb-repo' do
            command 'dnf config-manager --set-enabled crb'
            action :run
            not_if 'dnf repolist enabled | grep crb'
          end
        end
      when 'rocky', 'almalinux'
        if node['platform_version'].to_i == 8
          execute 'enable-powertools-repo' do
            command 'dnf config-manager --set-enabled powertools'
            action :run
            not_if 'dnf repolist enabled | grep powertools'
          end
        elsif node['platform_version'].to_i >= 9
          execute 'enable-crb-repo' do
            command 'dnf config-manager --set-enabled crb'
            action :run
            not_if 'dnf repolist enabled | grep crb'
          end
        end
      end
    end

    # Install packages - libyaml-devel is in RHEL 8 but not RHEL 9 (use libyaml instead)
    base_packages = %w[gcc gcc-c++ make patch openssl-devel zlib-devel libffi-devel readline-devel sqlite-devel bzip2 autoconf automake libtool bison json-devel]

    bash 'install epel-release && refresh cache' do
      code 'yum install -y epel-release && yum makecache'
    end

    package base_packages + ['libyaml-devel'] do
      action :install
    end
  when 'debian'
    package %w[build-essential libssl-dev libreadline-dev zlib1g-dev libsqlite3-dev libyaml-dev libffi-dev bison autoconf automake libtool] do
      action :install
    end
  end

  # Install RVM if not already installed
  bash 'install_rvm' do
    code <<-EOH
      if ! command -v rvm >/dev/null 2>&1; then
        gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
        curl -sSL https://get.rvm.io | bash -s stable
      fi
    EOH
    not_if 'command -v rvm'
  end

  # Source RVM and install Ruby
  bash "install_ruby_#{ruby_string}" do
    code <<-EOH
      source /etc/profile.d/rvm.sh
      rvm install #{ruby_string} --with-openssl-dir=/usr
      rvm use #{ruby_string} --default
    EOH
    not_if "bash -l -c 'rvm list | grep -q #{ruby_string}'"
  end

  if node['backup']['version_from_git?']
    package 'git'
    bash 'install_backup_from_git' do
      code <<-EOH
        source /etc/profile.d/rvm.sh
        rvm use #{ruby_string}

        # Clone the repo and build gem directly
        temp_dir=$(mktemp -d)
        cd $temp_dir
        git clone #{node['backup']['git_repo']} backup_repo
        cd backup_repo
        git checkout #{node['backup']['git_repo_revision']}

        # Build and install the gem
        gem build *.gemspec
        gem install *.gem

        # Clean up
        cd /
        rm -rf $temp_dir
      EOH
      not_if "bash -l -c 'rvm use #{ruby_string} && gem list backup | grep -q backup'"
    end
  else
    bash 'install_backup_gem' do
      code <<-EOH
        source /etc/profile.d/rvm.sh
        rvm use #{ruby_string}
        #{node['backup']['version'] ? "gem install backup -v '#{node['backup']['version']}'" : 'gem install backup'}
      EOH
      unless node['backup']['upgrade?']
        not_if "bash -l -c 'rvm use #{ruby_string} && gem list backup | grep -q backup'"
      end
    end
  end

  node['backup']['dependencies'].each do |gem, ver|
    bash "install_dependency_#{gem}" do
      code <<-EOH
        source /etc/profile.d/rvm.sh
        rvm use #{ruby_string}
        #{ver ? "gem install #{gem} -v '#{ver}'" : "gem install #{gem}"}
      EOH
      not_if "bash -l -c 'rvm use #{ruby_string} && gem list #{gem} | grep -q #{gem}'"
    end
  end
else
  if node['backup']['version_from_git?']
    # Install git if needed
    package 'git'

    # For non-RVM systems, we need gem_specific_install cookbook
    # Check if it's available before using it
    begin
      include_recipe 'gem_specific_install'

      gem_specific_install 'backup' do
        repository node['backup']['git_repo']
        revision node['backup']['git_repo_revision']
        action :install
      end
    rescue Chef::Exceptions::CookbookNotFound
      Chef::Log.warn('gem_specific_install cookbook not found. Installing backup gem from git requires this cookbook for non-RVM systems.')
      raise
    end
  else
    gem_package 'backup' do
      version node['backup']['version'] if node['backup']['version']
      action :upgrade if node['backup']['upgrade?']
    end
  end

  node['backup']['dependencies'].each do |gem, ver|
    gem_package gem do
      version ver if ver
    end
  end
end

%w( config_path model_path ).each do |dir|
  directory node['backup'][dir] do
    owner node['backup']['user']
    group node['backup']['group']
    mode '0700'
  end
end

template 'Backup config file' do
  path ::File.join(node['backup']['config_path'], 'config.rb')
  source 'config.rb.erb'
  owner node['backup']['user']
  group node['backup']['group']
  mode '0600'
end
