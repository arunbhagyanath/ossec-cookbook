#
# Cookbook Name:: ossec
# Recipe:: server
#
# Copyright 2010-2015, Chef Software, Inc.
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

node.set['ossec']['user']['install_type'] = 'server'
node.set['ossec']['server']['maxagents']  = 1024

include_recipe 'ossec'

template '/etc/init.d/ossec' do
  source 'ossec.service.erb'
  owner 'root'
  group 'root'
  mode 0755
end

dbag_name = node['ossec']['data_bag']['name']
dbag_item = node['ossec']['data_bag']['ssh']

if node['ossec']['data_bag']['encrypted']
  ossec_key = Chef::EncryptedDataBagItem.load(dbag_name, dbag_item)
else
  ossec_key = data_bag_item(dbag_name, dbag_item)
end

directory "#{node['ossec']['user']['dir']}/.ssh" do
  owner 'root'
  group 'ossec'
  mode 0750
end

template "#{node['ossec']['user']['dir']}/.ssh/id_rsa" do
  source 'ssh_key.erb'
  owner 'root'
  group 'ossec'
  mode 0600
  variables(key: ossec_key['privkey'])
end

execute 'create_certificate_for_authd' do
  command "openssl genrsa -out #{node['ossec']['user']['dir']}/etc/sslmanager.key 2048 && openssl req -new -x509 -key #{node['ossec']['user']['dir']}/etc/sslmanager.key -out #{node['ossec']['user']['dir']}/etc/sslmanager.cert -days 3650 -subj '/C=US/ST=Ossec/L=Ossec/O=Dis/CN=Ossec'"
  not_if "test -f #{node['ossec']['user']['dir']}/etc/sslmanager.cert"
end

agent_manager = "#{node['ossec']['user']['dir']}/bin/ossec-batch-manager.pl"

execute "#{agent_manager} -a --ip #{node['ipaddress']} -n #{node['fqdn']}" do
  not_if "grep '#{node[:fqdn]} #{node[:ipaddress]}' #{node['ossec']['user']['dir']}/etc/client.keys"
end
