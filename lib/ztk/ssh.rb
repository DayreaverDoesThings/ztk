################################################################################
#
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) Jove Labs
#     License: Apache License, Version 2.0
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
################################################################################

module ZTK
  class SSHError < Error; end
  class SSH

################################################################################

    attr_accessor :stdout, :stderr, :stdin, :config

################################################################################

    def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN)
      @stdout, @stderr, @stdin = stdout, stderr, stdin

      @stdout.sync = true if @stdout.respond_to?(:sync=)
      @stderr.sync = true if @stderr.respond_to?(:sync=)
      @stdin.sync = true if @stdin.respond_to?(:sync=)

      @config = Hash.new(nil)
    end

################################################################################

    def console
      $logger and $logger.debug { "config(#{@config.inspect})" }

      command = [ "ssh" ]
      command << [ "-q" ]
      command << [ "-o", "UserKnownHostsFile=/dev/null" ]
      command << [ "-o", "StrictHostKeyChecking=no" ]
      command << [ "-o", "KeepAlive=yes" ]
      command << [ "-o", "ServerAliveInterval=60" ]
      command << [ "-i", @config[:identity_file] ] if @config[:identity_file]
      command << [ "-o", "ProxyCommand=\"#{proxy_command}\"" ] if @config[:proxy]
      command << "#{@config[:ssh_user]}@#{@config[:host]}"
      command = command.flatten.compact.join(" ")
      $logger and $logger.info { "command(#{command})" }
      Kernel.exec(command)
    end

################################################################################

    def exec(command, options={})
      @ssh ||= Net::SSH.start(@config[:host], @config[:ssh_user], ssh_options)

      options = { :silence => false }.merge(options)
      silence = options[:silence]
      output = ""

      $logger and $logger.debug { "config(#{@config.inspect})" }
      $logger and $logger.debug { "options(#{options.inspect})" }
      $logger and $logger.info { "command(#{command})" }
      channel = @ssh.open_channel do |chan|
        $logger and $logger.debug { "channel opened" }
        chan.exec(command) do |ch, success|
          raise SSHError, "Could not execute '#{command}'." unless success

          ch.on_data do |c, data|
            output += data
            $logger and $logger.debug { data.chomp.strip }
            @stdout.print(data) if !silence
          end

          ch.on_extended_data do |c, type, data|
            output += data
            $logger and $logger.debug { data.chomp.strip }
            @stderr.print(data) if !silence
          end

        end
      end
      channel.wait
      $logger and $logger.debug { "channel closed" }

      output
    end

################################################################################

    def upload(local, remote)
      @sftp ||= Net::SFTP.start(@config[:host], @config[:ssh_user], ssh_options)

      $logger and $logger.debug { "config(#{@config.inspect})" }
      $logger and $logger.info { "parameters(#{local},#{remote})" }
      @sftp.upload!(local.to_s, remote.to_s) do |event, uploader, *args|
        case event
        when :open
          $logger and $logger.info { "upload(#{args[0].local} -> #{args[0].remote})" }
        when :close
          $logger and $logger.debug { "close(#{args[0].remote})" }
        when :mkdir
          $logger and $logger.debug { "mkdir(#{args[0]})" }
        when :put
          $logger and $logger.debug { "put(#{args[0].remote}, size #{args[2].size} bytes, offset #{args[1]})" }
        when :finish
          $logger and $logger.info { "finish" }
        end
      end
    end

################################################################################

    def download(remote, local)
      @sftp ||= Net::SFTP.start(@config[:host], @config[:ssh_user], ssh_options)

      $logger and $logger.debug { "config(#{@config.inspect})" }
      $logger and $logger.info { "parameters(#{remote},#{local})" }
      @sftp.download!(remote.to_s, local.to_s) do |event, downloader, *args|
        case event
        when :open
          $logger and $logger.info { "download(#{args[0].remote} -> #{args[0].local})" }
        when :close
          $logger and $logger.debug { "close(#{args[0].local})" }
        when :mkdir
          $logger and $logger.debug { "mkdir(#{args[0]})" }
        when :get
          $logger and $logger.debug { "get(#{args[0].remote}, size #{args[2].size} bytes, offset #{args[1]})" }
        when :finish
          $logger and $logger.info { "finish" }
        end
      end
    end


################################################################################
  private
################################################################################

    def proxy_command
      $logger and $logger.debug { "config(#{@config.inspect})" }

      if !@config[:identity_file]
        message = "You must specify an identity file in order to SSH proxy."
        $logger and $logger.fatal { message }
        raise SSHError, message
      end

      command = ["ssh"]
      command << [ "-q" ]
      command << [ "-o", "UserKnownHostsFile=/dev/null" ]
      command << [ "-o", "StrictHostKeyChecking=no" ]
      command << [ "-o", "KeepAlive=yes" ]
      command << [ "-o", "ServerAliveInterval=60" ]
      command << [ "-i", @config[:proxy_identity_file] ] if @config[:proxy_identity_file]
      command << "#{@config[:proxy_ssh_user]}@#{@config[:proxy_host]}"
      command << "nc %h %p"
      command = command.flatten.compact.join(" ")
      $logger and $logger.debug { "command(#{command})" }
      command
    end

################################################################################

    def ssh_options
      $logger and $logger.debug { "config(#{@config.inspect})" }
      options = {}
      options.merge!(:password => @config[:ssh_password]) if @config[:ssh_password]
      options.merge!(:keys => @config[:identity_file]) if @config[:identity_file]
      options.merge!(:timeout => @config[:timeout]) if @config[:timeout]
      options.merge!(:user_known_hosts_file  => '/dev/null') if !@config[:host_key_verify]
      options.merge!(:proxy => Net::SSH::Proxy::Command.new(proxy_command)) if @config[:proxy]
      $logger and $logger.debug { "options(#{options.inspect})" }
      options
    end

################################################################################

  end
end

################################################################################
