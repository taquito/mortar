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

require "erb"
require 'tempfile'
require "mortar/helpers"
require "mortar/local/installutil"

class Mortar::Local::Sqoop
  include Mortar::Local::InstallUtil

  SQOOP_URL = "http://apache.mirror.quintex.com/sqoop/1.4.4/sqoop-1.4.4.bin__hadoop-1.0.0.tar.gz"
  HADOOP_URL = "https://archive.apache.org/dist/hadoop/core/hadoop-1.0.3/hadoop-1.0.3-bin.tar.gz"

  def install_or_update
    @command = "#{local_install_directory}/python/bin/python"
    if should_do_install?
      action "Installing sqoop to #{local_install_directory_name}" do
        do_install
      end
    elsif should_do_update?
      action "Updating to latest sqoop in #{local_install_directory_name}" do
        do_install
      end
    end
    true
  end

  def sqoop_url
    return ENV.fetch('SQOOP_DISTRO_URL', SQOOP_URL)
  end
  def hadoop_url
    return ENV.fetch('HADOOP_DISTRO_URL', HADOOP_URL)
  end

  def should_do_install?
    return ((not (File.exists?(sqoop_directory))) or (not (File.exists?(hadoop_directory))))
  end

  def should_do_update?
    return (is_newer_version('sqoop', sqoop_url) or is_newer_version('hadoop', hadoop_url))
  end

  def sqoop_directory
    return "#{local_install_directory}/sqoop"
  end
  def hadoop_directory
    return "#{local_install_directory}/hadoop"
  end

  def sqoop_dir_in_tgz
    File.basename(sqoop_url).split('.')[0..-3].join('.')
  end
  def hadoop_dir_in_tgz
    File.basename(hadoop_url).split('.')[0..-3].join('.').split('-')[0..1].join('-')
  end

  def do_install
    do_hadoop_install
    do_sqoop_install
  end

  def do_hadoop_install
    local_tgz = File.join(local_install_directory, File.basename(hadoop_url))
    if File.exists?(local_tgz)
      FileUtils.rm(local_tgz)
    end
    download_file(hadoop_url, local_tgz)

    if File.exists?(hadoop_directory)
      FileUtils.rm_rf(hadoop_directory)
    end

    extract_tgz(local_tgz, local_install_directory)

    FileUtils.mv(File.join(local_install_directory, hadoop_dir_in_tgz), hadoop_directory)

    # This has been seening coming out of the tgz w/o +x so we do
    # here to be sure it has the necessary permissions
    FileUtils.chmod(0755, "#{hadoop_directory}/bin/hadoop")

    File.delete(local_tgz)
    note_install("hadoop")
  end

  def do_sqoop_install
    local_tgz = File.join(local_install_directory, File.basename(sqoop_url))
    if File.exists?(local_tgz)
      FileUtils.rm(local_tgz)
    end
    download_file(sqoop_url, local_tgz)

    if File.exists?(sqoop_directory)
      FileUtils.rm_rf(sqoop_directory)
    end

    extract_tgz(local_tgz, local_install_directory)

    FileUtils.mv(File.join(local_install_directory, sqoop_dir_in_tgz), sqoop_directory)

    # This has been seening coming out of the tgz w/o +x so we do
    # here to be sure it has the necessary permissions
    FileUtils.chmod(0755, "#{sqoop_directory}/bin/sqoop")

    File.delete(local_tgz)
    note_install("sqoop")
  end

  def sqoop_command_script_template_path
    File.expand_path("../../templates/script/sqoop.sh", __FILE__)
  end

  def hadoop_home
    "#{local_install_directory}/hadoop"
  end

  def export(connstr, dbtable, s3dest, options)
    template_params = sqoop_export_template_parameters(connstr, dbtable, s3dest, options)
    return run_templated_script(sqoop_command_script_template_path, template_params)
  end

  def sqoop_export_template_parameters(connstr, dbtable, s3dest, options)
    pig = Mortar::Local::Pig.new()
    parameters = {
      "sqoop_dir" => sqoop_directory,
      "jdb_conn_string" => connstr,
      "dbtable" => dbtable,
      "destination" => s3dest,
      "hadoop_home" => hadoop_home,
      "classpath" => pig.template_params_classpath,
      "dbtable" => dbtable,
      "jdbc_conn" => connstr,
      "s3dest" => s3dest,
      "sqoop_opts" => sqoop_java_options
    }
    parameters["dbuser"] = options[:username] if options[:username]
    parameters["dbpass"] = options[:password] if options[:password]
    parameters["jdbcdriver"] = options[:jdbcdriver] if options[:jdbcdriver]
    parameters["direct_import"] = true if options[:direct]
    return parameters
  end

  def sqoop_java_options
    opts = {}
    opts['fs.s3n.awsAccessKeyId'] = ENV['AWS_ACCESS_KEY']
    opts['fs.s3n.awsSecretAccessKey'] = ENV['AWS_SECRET_KEY']
    opts['fs.s3.awsAccessKeyId'] = ENV['AWS_ACCESS_KEY']
    opts['fs.s3.awsSecretAccessKey'] = ENV['AWS_SECRET_KEY']
    return opts
  end

end