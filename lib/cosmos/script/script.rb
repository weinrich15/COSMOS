# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/io/json_drb_object'
require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server'
require 'cosmos/script/cmd_tlm_server'
require 'cosmos/script/replay'
require 'cosmos/script/commands'
require 'cosmos/script/telemetry'
require 'cosmos/script/limits'
require 'cosmos/script/scripting'
require 'cosmos/script/tools'

$cmd_tlm_server = nil
$disconnected_targets = nil
$cmd_tlm_replay_mode = false

module Cosmos
  class CheckError < RuntimeError; end
  class StopScript < StandardError; end
  class SkipTestCase < StandardError; end

  class ServerProxy
    def initialize(config_file)
      if $disconnected_targets
        # Start up a standalone CTS in disconnected mode
        @disconnected = CmdTlmServer.new(config_file, false, true)
      end
      # Start a Json connect to the real server
      if $cmd_tlm_replay_mode
        @cmd_tlm_server = JsonDRbObject.new(System.connect_hosts['REPLAY_API'], System.ports['REPLAY_API'])
      else
        @cmd_tlm_server = JsonDRbObject.new(System.connect_hosts['CTS_API'], System.ports['CTS_API'])
      end
    end

    def method_missing(method_name, *method_params)
      if method_params.length == 1
        target = method_params[0].split(" ")[0]
      else
        target = method_params[0]
      end
      if $disconnected_targets && $disconnected_targets.include?(target)
        @disconnected.send(method_name, *method_params)
      else
        @cmd_tlm_server.method_missing(method_name, *method_params)
      end
    end
  end

  module Script
    # All methods are private so they can only be called by themselves and not
    # on another object. This is important for the JsonDrbObject class which we
    # use to communicate with the server. JsonDrbObject implements method_missing
    # to forward calls to the remote service. If these methods were not private,
    # they would be included on the $cmd_tlm_server global and would be
    # called directly instead of being forwarded over the JsonDrb connection to
    # the real server.
    private

    # Called when this module is mixed in using "include Cosmos::Script"
    def self.included(base)
      $disconnected_targets = nil
      $cmd_tlm_replay_mode = false
      $cmd_tlm_server = nil
      initialize_script_module()
    end

    def initialize_script_module(config_file = CmdTlmServer::DEFAULT_CONFIG_FILE)
      $cmd_tlm_server = ServerProxy.new(config_file)
    end

    def shutdown_cmd_tlm
      $cmd_tlm_server.shutdown if $cmd_tlm_server
    end

    def set_disconnected_targets(targets, config_file = CmdTlmServer::DEFAULT_CONFIG_FILE)
      $disconnected_targets = targets
      initialize_script_module(config_file)
    end

    def get_disconnected_targets
      return $disconnected_targets
    end

    def clear_disconnected_targets
      $disconnected_targets = nil
    end

    def script_disconnect
      $cmd_tlm_server.disconnect if $cmd_tlm_server
    end

    def set_replay_mode(replay_mode)
      if replay_mode != $cmd_tlm_replay_mode
        $cmd_tlm_replay_mode = replay_mode
        initialize_script_module()
      end
    end

    def get_replay_mode
      $cmd_tlm_replay_mode
    end
  end
end
