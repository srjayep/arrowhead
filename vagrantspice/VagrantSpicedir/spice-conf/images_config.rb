
{
  'CentOS-6.5-x64' => {
    :commands => {

      :puppetmaster_install => proc {|config_param| "
        sleep 60

        if which puppet > /dev/null 2>&1; then
          echo 'Puppet Installed.'
        else
          echo 'Installing Puppet Master.'
          rpm -Uvh http://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-10.noarch.rpm
          yum --nogpgcheck -y install puppet-server
          echo '*.#{config_param[:domain]}' > /etc/puppet/autosign.conf
          puppet module install puppetlabs-stdlib
          puppet module install puppetlabs-firewall
          puppet module install puppetlabs-java
          puppet module install dalen-dnsquery
          puppet config set --section master certname puppetmaster.#{config_param[:domain]}
          iptables -F
          iptables -A INPUT -i lo -j ACCEPT
          iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
          iptables -A INPUT -p tcp --dport ssh -j ACCEPT
          iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 8140 --tcp-flags FIN,SYN,RST,ACK SYN -j ACCEPT
          iptables -A INPUT -j DROP

          # three options for overwriting puppet config and modules
          yum install -y git
          git clone #{config_param[:repo_url]} /tmp/vagrant-puppet-scaleio
          cp -Rf /tmp/vagrant-puppet-scaleio/puppet/* /etc/puppet/.

          #rsync it to /opt and copy it from there
          cp -Rf /opt/puppet/* /etc/puppet/. &> /dev/null

          #object store transfered
          if [ -e '/tmp/puppet.tar.gz' ]; then
            tar -zxvf /tmp/puppet.tar.gz -C /etc
          fi

          cp -Rf /opt/sync/puppet /etc/puppet/.

          /usr/bin/puppet resource service puppetmaster ensure=running enable=true
        fi
      "},
      :puppetmaster_sitepp_copy => proc {|from| "
        cp -f #{from} /etc/puppet/manifests/site.pp
      " },
      :puppetagent_install => proc {|config_param| "
        sleep 60

        if which puppet > /dev/null 2>&1; then
          echo 'Puppet Installed.'
        else
          echo 'Installing Puppet Agent.'
          rpm -Uvh http://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-10.noarch.rpm
          yum --nogpgcheck -y install puppet
          puppet config set --section main server puppetmaster.#{config_param[:domain]}
          puppet agent -t --detailed-exitcodes || [ $? -eq 2 ]
        fi
      "},
      :puppetmaster_remove => "sudo rpm -e puppet-server --nodeps &> /dev/null",
      :puppetagent_remove => "sudo rpm -e puppet --nodeps &> /dev/null",
    }
  },
  'CentOS-7-x64' => {
    :commands => {
      :puppetmaster_install => proc {|config_param| "
        sleep 60
        if which puppet > /dev/null 2>&1; then
          echo 'Puppet Installed.'
        else
          yum remove -y firewalld && yum install -y iptables-services && iptables --flush

          echo 'Installing Puppet Master.'
          rpm -ivh http://yum.puppetlabs.com/el/7/products/x86_64/puppetlabs-release-7-10.noarch.rpm
          yum --nogpgcheck -y install puppet-server
          echo '*.#{config_param[:domain]}' > /etc/puppet/autosign.conf
          puppet config set --section master certname puppetmaster.#{config_param[:domain]}
          /usr/bin/puppet resource service iptables ensure=stopped enable=false
        fi

        /usr/bin/puppet resource service puppetmaster ensure=running enable=true

      "},
      :puppetmaster_install_scaleio => proc {|config_param| "
        puppet module install puppetlabs-stdlib
        puppet module install puppetlabs-firewall
        puppet module install puppetlabs-java
        puppet module install emccode-scaleio
        puppet config set --section main parser future

        cp -Rf /opt/sync/puppet/* /etc/puppet/.

        sh /opt/sync/copyrpms.sh

        systemctl restart puppetmaster
      "},
      :puppetmaster_sitepp_copy => proc {|from| "
        cp -f #{from} /etc/puppet/manifests/site.pp
      " },
      :puppetagent_install => proc {|config_param| "
        sleep 60

        if which puppet > /dev/null 2>&1; then
          echo 'Puppet Installed.'
        else
          yum remove -y firewalld && yum install -y iptables-services && iptables --flush

          echo 'Installing Puppet Agent.'
          rpm -ivh http://yum.puppetlabs.com/el/7/products/x86_64/puppetlabs-release-7-10.noarch.rpm
          yum --nogpgcheck -y install puppet
          puppet config set --section main server puppetmaster.#{config_param[:domain]}
          puppet agent -t --detailed-exitcodes || [ $? -eq 2 ]
        fi

      "},
      :puppetagent_install_docker_scaleio => proc {|config_param| "
        if which docker > /dev/null 2>&1; then
          echo 'Docker Installed.'
          systemctl stop docker
        else
          yum install -y docker
        fi
        rm -Rf /var/lib/docker

        if which screen > /dev/null 2>&1; then
          echo 'Screen installed.'
        else
          yum install -y screen
        fi

        chmod +x /opt/schelper/schelper.sh
        /usr/bin/screen -m -d bash -c '/opt/schelper/schelper.sh'
      "},
      :puppetmaster_remove => "sudo rpm -e puppet-server --nodeps &> /dev/null",
      :puppetagent_remove => "sudo rpm -e puppet --nodeps &> /dev/null",
    }
  },
  'default_linux' => {
    :commands => {
      :set_hostname => proc {|hostname,domain| "
              echo 'Setting Hostname'
              echo '#{hostname}.#{domain}' > /etc/hostname
              hostname `cat /etc/hostname`
      "},
      :dns_update => 'echo -e "DNS1=8.8.4.4\nDNS2=8.8.8.8" >> /etc/sysconfig/network-scripts/ifcfg-eth0',
      :curl_file => proc {|from_url,to_path| "
        yum install -y curl
        mkdir -p #{File.dirname(to_path)}
        curl #{from_url} -o #{to_path}
      "}
    },
  }
}
