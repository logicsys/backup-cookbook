# Support whyrun

action :create do
  cron_options = new_resource.cron_options || {}
  cron_output_redirect = if cron_options.key?(:output_log)
                           "2>&1 >> #{cron_options[:output_log]}"
                         else
                           '> /dev/null'
                         end

  cron_trigger = new_resource.name

  if new_resource.date == :yesterday
    cron_trigger += '-$( date -d yesterday +\\%F  )'
  elsif new_resource.date == :today
    cron_trigger += '-$( date +\\%F )'
  elsif !new_resource.date.nil?
    raise "Invalid date: '#{new_resource.date}' - valid :today or :yesterday"
  end

  backup_cmd_path = if node['backup']['use_rvm'] == true
                      '/usr/local/rvm/wrappers/ruby-3.3.9/backup'
                    else
                      'backup'
                    end

  cron_d cron_name do
    command cron_options[:command] ||
            "cd /tmp/ ; backup_cmd_path perform --trigger #{cron_trigger} \
            --config-file #{node['backup']['config_path']}/config.rb \
            --log-path=#{node['backup']['log_path']} #{node['backup']['addl_flags']} \
            #{cron_output_redirect}".squeeze(' ')

    mailto cron_options[:mailto] if cron_options.key?(:mailto)
    path cron_options[:path] if cron_options.key?(:path)
    shell cron_options[:shell] if cron_options.key?(:shell)
    user cron_options[:user] || node['backup']['user']
    home cron_options[:home] if cron_options.key?(:home)
    environment cron_options[:environment] if cron_options.key?(:environment)

    minute new_resource.schedule[:minute] || '*'
    hour new_resource.schedule[:hour] || '*'
    day new_resource.schedule[:day] || '*'
    month new_resource.schedule[:month] || '*'
    weekday new_resource.schedule[:weekday] || '*'
  end unless new_resource.schedule.nil?

  template "Model file for #{new_resource.name}" do
    path ::File.join(node['backup']['model_path'], "#{new_resource.name}.rb")
    source 'model.erb'
    cookbook new_resource.cookbook
    owner node['backup']['user']
    group node['backup']['group']
    mode '0600'
    variables(
      name: new_resource.name,
      description: new_resource.description || new_resource.name,
      definition: new_resource.definition,
      date: new_resource.date
    )
    if new_resource.template.is_a? Hash
      new_resource.template.each { |k, v| send k, v }
    end
  end
end

action :delete do
  cron_d cron_name do
    action :delete
  end

  file "Model file for #{new_resource.name}" do
    path ::File.join(node['backup']['model_path'], "#{new_resource.name}.rb")
    action :delete
  end
end

private

def cron_name
  "#{new_resource.name}_backup"
end
