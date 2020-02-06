# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2015 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fileutils'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/container'
require 'java_buildpack/util/java_main_utils'


module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for JEUS applications.
    class Lenaw < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile

        # GET LENA FILE PATH
        lenaBinPath = "/tmp/buildpackdownloads/"
        tmpDirPathArr = Dir.entries(lenaBinPath)
        lenaBinPath = lenaBinPath+tmpDirPathArr[2]+"/binary"
        print "==== 1. lenaBinPath : #{lenaBinPath} \n"
        lenaInstallScriptPath = lenaBinPath + "/installScript/"
        lenaInstallScriptPathArr = Dir.entries(lenaInstallScriptPath)
        lenaInstallScriptPath = lenaInstallScriptPath + lenaInstallScriptPathArr[2]
        print "==== 3. lenaInstallScriptPath : #{lenaInstallScriptPath} \n" 
        print "=== @droplet.sandbox : #{@droplet.sandbox} \n"

        # move install shell
        move_to(lenaInstallScriptPath,@droplet.sandbox)
        # run install shell
        runShPath = "#{@droplet.sandbox}/"+ lenaInstallScriptPathArr[2]
        # print "==== 4. runShPath : #{runShPath} \n"         

        download(@version, @uri) { |file| expand file }

        # Call Lena Install shell
        run_sh runShPath
        print "=== end complile ==== \n"
        link_to(@application.root.children, root)
        
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        #  shell "top"
        # #/home/vcap/app/.java-buildpack/lena
        @droplet.environment_variables.add_environment_variable 'JAVA_OPTS', '$JAVA_OPTS'
        @droplet.java_opts.add_system_property 'http.port', '$PORT'

        [
          @droplet.environment_variables.as_env_vars,
          @droplet.java_home.as_env_var,
          'exec',
          "$PWD/#{(@droplet.sandbox + 'servers/webServer/start.sh').relative_path_from(@droplet.root)}",
          'run'
        ].flatten.compact.join(' ')

      end

      protected

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def supports?
        # web_inf? && !JavaBuildpack::Util::JavaMainUtils.main_class(@application)
        true
      end

      private

      def copy_application
        #link_to(@application.root.children, root)
        FileUtils.mkdir_p root
        @application.root.children.each { |child| FileUtils.cp_r child, root }
      end

      def create_dodeploy #debug jboss
        FileUtils.touch(webapps + 'ROOT.war.dodeploy')
      end

      def root
        @droplet.sandbox + 'webhome/autodeploy/test'
      end

      def web_inf?
        (@application.root + 'WEB-INF').exist?
      end

      def expand(file)
        with_timing "Expanding #{@component_name} to #{@droplet.sandbox.relative_path_from(@droplet.root)}" do
          FileUtils.mkdir_p @droplet.sandbox
          
          shell "tar xzf #{file.path} -C #{@droplet.sandbox} --strip 1 --exclude webapps 2>&1"

          @droplet.copy_resources

            tarPath = "/tmp/app/.java-buildpack/lenaw/"
         tmpDirPathArr = Dir.entries(tarPath)
         print "==== 1. tmpDirPathArr : #{tmpDirPathArr} \n"
        
        end
      end

      def expandByPath(filePath)
        with_timing "Expanding By Path #{@component_name} to #{@droplet.sandbox.relative_path_from(@droplet.root)}" do
          FileUtils.mkdir_p @droplet.sandbox
          
          shell "tar xzf #{filePath} -C #{@droplet.sandbox} --strip 1 --exclude webapps 2>&1"

          @droplet.copy_resources

          print "------------------------ Expanding By Path LENA --------------------------"
          
        end
      end

      def link_to(source, destination)
        FileUtils.mkdir_p destination
        source.each { |path| (destination + path.basename).make_symlink(path.relative_path_from(destination)) }

        print "==== source path : #{source} \n"
        print "==== destination path : #{destination} \n"
        # sourceArr = Dir.entries(source)
        #  print "==== 1. sourceArr : #{sourceArr} \n"
         destinationArr = Dir.entries(destination)
         print "==== 1. destinationArr : #{destinationArr} \n"

         # proxy path
        proxyPath = "/tmp/app/.java-buildpack/lenaw/servers/webServer/conf/extra/proxy/proxy_vhost_default.conf"
        userProxyFilePath = destination+"/proxy.conf"
        print "=== userProxyFilePath : #{userProxyFilePath}"
        
        move_to(userProxyFilePath,proxyPath)
      end

      def move_to(source, destination)
        print "==== move file from  #{source} to #{destination}  ==== \n"
        FileUtils.mkdir_p destination
        shell "mv #{source} #{destination}" 
      end

      def run_sh(shPath)
        print "==== run shell #{shPath} ==== \n"
        shell "chmod 755 #{shPath}"
        print "==== call shell ==== \n"
        shell "sh #{shPath}"       
        print "==== end shell ==== \n"
        
      end

    end

  end
end