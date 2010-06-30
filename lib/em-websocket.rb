require "eventmachine"

$:.unshift(File.dirname(__FILE__))
require "em-websocket/server"
require "em-websocket/client"