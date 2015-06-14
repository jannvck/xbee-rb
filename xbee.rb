#!/usr/bin/env ruby
require "serialport"
require "observer"
require 'logger'

class UARTDataFrame
	def initialize(data)
		raise 'Data has to be an Array of bytes' unless data.is_a? Array
		@data = data
	end
	def getDataBytes
		@data
	end
	def getBytes
		return [0x7E].pack('C') +
			[@data.length].pack('n') +
			@data.pack('C*') +
			checksum
	end
	def getBytesEscaped
		getBytes.unpack('C*').map{|v|
			if v.object_id == 0x7E.object_id ||
				v.object_id == 0x7D.object_id ||
				v.object_id == 0x11.object_id ||
				v.object_id == 0x13.object_id
					[0x7D, v ^ 0x20]
			else
				v
			end}.flatten.pack('C*')
	end
	def checksum
		return [0xFF - @data.reduce(:+)].pack('C')
	end
	def inspect
		puts "dataBytes=#{@data.length}"
		puts "bytes=#{getBytes.unpack('C*')}"
		puts "checksum=#{checksum.unpack('C').first}"
	end
end

module APIFrames
	CmdIDs = [
		[ "AT_COMMAND", 0x08 ],
		[ "AT_COMMAND_RESPONSE", 0x88 ],
		[ "AT_COMMAND_QUEUE_PARAMETER_VALUE", 0x09 ],
		[ "ZIGBEE_TRANSMIT_REQUEST", 0x10 ],
		[ "ZIGBEE_EXPLICIT_ADDRESSING_COMMAND", 0x11 ],
		[ "REMOTE_COMMAND_REQUEST", 0x17 ],
		[ "CREATE_SOURCE_ROUTE", 0x21 ],
		[ "AT_COMMAND_RESPONSE", 0x88 ],
		[ "MODEM_STATUS", 0x8A ],
		[ "ZIGBEE_TRANSMIT_STATUS", 0x8B ],
		[ "ZIGBEE_RECEIVE_PACKET", 0x90 ],
		[ "ZIGBEE_EXPLICIT_RX_INDICATOR", 0x91 ],
		[ "ZIGBEE_IO_DATA_SAMPLE_RX_INDICATOR", 0x92 ],
		[ "XBEE_SENSOR_READ_INDICATOR", 0x94 ],
		[ "NODE_IDENTIFICATION_INDICATOR", 0x95 ],
		[ "REMOTE_COMMAND_RESPONSE", 0x97 ],
		[ "OVER-THE-AIR_FIRMWARE_UPDATE_STATUS", 0xA0 ],
		[ "ROUTE_RECORD_INDICATOR", 0xA1 ],
		[ "MANY-TO-ONE_ROUTE_REQUEST_INDICATOR", 0xA3 ]
	]
	def getType
		begin
			CmdIDs.fetch(CmdIDs.index{|a| a.last == @data[0]}).first
		rescue
			"NO_TYPE"
		end
	end
end

class APIFrame
	include APIFrames
	def initialize(data)
		@data = data
	end
	def getBytes
		@data
	end
	def addr64ToByteArray(addr)
		if addr.is_a? Fixnum
			return [addr].pack('Q').bytes.to_a.reverse
		elsif addr.is_a? String
			return [addr.to_i(16)].pack('Q').bytes.to_a.reverse
		elsif addr.is_a? Array
			return addr
		else
			raise "Can't convert #{addr.class} to byte array"
		end
	end
	def addr16ToByteArray(addr)
		if addr.is_a? Fixnum
			return [addr].pack('S').bytes.to_a.reverse
		elsif addr.is_a? String
			return [addr.to_i(16)].pack('S').bytes.to_a.reverse
		elsif addr.is_a? Array
			return addr
		else
			raise "Can't convert #{addr.class} to byte array"
		end
	end
end

class ATCommand < APIFrame
	##
	# Hand parameters as associative array.
	#
	# == Parameters:
	# @param data frame buffer
	# @param frameID frame ID
	# @param atCommand AT command, e.g. "IS"
	# @param parameterValue AT command parameter
	def initialize(opts)
		super(opts[:data])
		if (opts[:data] != nil && opts[:data].length < 4 || opts[:data].length < 5 &&
			opts[:parameterValue] != nil)
			raise "Invalid data"
		end
		if opts[:data] == nil
			@data = []
			@data[0] = CmdIDs.assoc("AT_COMMAND").last
			@data[1] = opts[:frameID]
			raise "No AT command specified" unless opts[:atCommand] != nil
			opts[:atCommand] = opts[:atCommand].bytes.to_a if opts[:atCommand].is_a? String
			opts[:atCommand].each_index{|i| @data.insert(2+i, opts[:atCommand][i])}
			@data = @data + opts[:parameterValue] if opts[:parameterValue] != nil
			@data.collect! {|x| if x == nil; 0 else x end }
		end
	end
	def getFrameID
		@data[1]
	end
	def getATCommand
		@data[2..3]
	end
	def getParameterValue
		if @data.length > 4
			@data[4..-1]
		else
			nil
		end
	end
	def inspect
		puts "ATCommand"
		puts "frameID=#{getFrameID}"
		puts "atCommand=#{getATCommand.pack('C*')}"
		puts "parameterValue=#{getParameterValue}"
	end
end

class ATCommandResponse < APIFrame
	##
	# Hand parameters as associative array.
	#
	# == Parameters:
	# @param data frame buffer
	# @param frameID
	# @param atCommand
	# @param commandStatus
	# @param commandData
	def initialize(opts)
		super(opts[:data])
                if (opts[:data] != nil &&  opts[:data].length < 3 || opts[:data].length < 5 &&
                        opts[:parameterValue] != nil)
                        raise "Invalid data"
                end
                if opts[:data] == nil
                	@data = []
                	@data[0] = CmdIDs.assoc("AT_COMMAND_RESPONSE").last
                        @data[1] = opts[:frameID]
                        raise "No AT command specified" unless opts[:atCommand] != nil
                        opts[:atCommand] = opts[:atCommand].bytes.to_a if opts[:atCommand].is_a? String
                        opts[:atCommand].each_index{|i| @data.insert(2+i, opts[:atCommand][i])}
			opts[:commandStatus] = opts[:commandStatus].bytes.to_a if opts[:commandStatus].is_a? String
			@data[4] = opts[:commandStatus]
			opts[:commandData] = opts[:commandData].bytes.to_a if opts[:commandData].is_a? String
                        @data = @data + opts[:commandData] if opts[:commandData] != nil
                        @data.collect! {|x| if x == nil; 0 else x end }
                end
	end
	def getFrameID
		@data[1]
	end
	def getATCommand
		@data[2..3]
	end
	def getCommandStatus
		@data[4]
	end
	def getCommandData
		if @data.length > 5
			@data[5..-1]
		else
			nil
		end
	end
	def inspect
		puts "ATCommandResponse"
		puts "frameID=#{getFrameID}"
		puts "atCommand=#{getATCommand.pack('C*')}"
		puts "commandStatus=#{getCommandStatus}"
		puts "commandData=#{getCommandData}"
		puts "commandData(hex)=#{getCommandData.pack('C*').unpack('H*').first}"
		puts "commandData(ascii)=#{getCommandData.map{|n| n.chr}.reduce(:+)}"
	end
end

class ZigBeeIODataSampleRxIndicator < APIFrame
	# opts hash arguments
	# ::sourceAddr
	# ::netAddr
	# ::isBroadcast
	# ::digitalChannelMask
	# ::analogChannelMask
	# ::digitalSamples
	# ::analogSamples
	def initialize(opts)
		super(opts[:data])
                if (opts[:data] != nil && opts[:data].length < 15 ||
				getDigitalChannelMask.reduce(:+) > 0 && opts[:data].length < 17 ||
				getAnalogChannelMask.to_i > 0 && opts[:data].length < 16 ||
				getDigitalChannelMask.reduce(:+) > 0 && getAnalogChannelMask.to_i > 0 &&
				opts[:data].length < 19 || opts[:data].length > 19)
                	raise "Invalid data"
                end
                if opts[:data] == nil
                	@data = []
                	@data[0] = CmdIDs.assoc("ZIGBEE_IO_DATA_SAMPLE_RX_INDICATOR").last
                        @data[1] = opts[:frameID]
                        @data += addr64ToByteArray(opts[:sourceAddr])
			@data += addr16ToByteArray(opts[:netAddr])
			@data[11] = opts[:isBroadcast]
			opts[:digitalChannelMask] = opts[:digitalChannelMask].bytes.to_a if opts[:digitalChannelMask].is_a? String
                        opts[:digitalChannelMask].each_index{|i| @data.insert(12+i, opts[:digitalChannelMask][i])}
                        opts[:analogChannelMask] = opts[:analogChannelMask].bytes.to_a if opts[:analogChannelMask].is_a? String
                        @data[15] = opts[:analogChannelMask]
                        if opts[:digitalChannelMask].reduce(:+) > 0
                        	opts[:digitalSamples] = opts[:digitalSamples].bytes.to_a if opts[:digitalSamples].is_a? String
                        	opts[:digitalSamples].each_index{|i| @data.insert(16+i, opts[:digitalSamples][i])}
                        end
                        if opts[:analogChannelMask].reduce(:+) > 0
                        	opts[:analogSamples] = opts[:analogSamples].bytes.to_a if opts[:analogSamples].is_a? String
                        	@data[19] = opts[:analogSamples]
                        end
                        @data.collect! {|x| if x == nil; 0 else x end }
                end
	end
	def getSourceAddr
		@data[1..8]
	end
	def getNetAddr
		@data[9..10]
	end
	def wasBroadcast?
		if @data[11].to_i == 2
			true
		else
			false
		end
	end
	def getDigitalChannelMask
		@data[13..14]
	end
	def getAnalogChannelMask
		@data[15]
	end
	def getDigitalSamples
		@data[16..17]
		if getDigitalChannelMask.reduce(:+) > 0
			@data[16..17]
		else
			puts "warning: No digital IO lines have sampling enabled!"
			nil
		end
	end
	def getAnalogSamples
		@data[19]
		if getAnalogChannelMask.to_i > 0
			@data[19]
		else
			puts "warning: No analog IO lines have sampling enabled!"
			nil
		end
	end
	def inspect
		puts "ZigBeeIODataSampleRxIndicator"
		puts "source=#{getSourceAddr.pack('C*').unpack('H*').first}"
		puts "network=#{getNetAddr.pack('C*').unpack('H*').first}"
		puts "broadcast=#{wasBroadcast?}"
		puts "digitalChannelMask=#{getDigitalChannelMask.pack('C*').unpack('B*').first}"
		puts "analogChannelMask=#{[getAnalogChannelMask].pack('C*').unpack('B*').first}"
		puts "digitalSamples=#{getDigitalSamples.pack('C*').
			unpack('B*').first}" if getDigitalChannelMask.reduce(:+) > 0
		puts "analogSamples=#{[getAnalogSamples].pack('C*').
			unpack('H*').first}" if getAnalogChannelMask.to_i > 0
	end
end

class ModemStatus < APIFrame
	def getStatus
		@data[1]
	end
end

class RemoteCommandRequest < APIFrame
	# opts hash arguments
	# ::data
	# ::frameID
	# ::destAddr
	# ::netAddr
	# ::remoteCommandOpts
	# ::atCommand
	# ::commandParameter (optional)
	def initialize(opts)
		super(opts[:data])
		if (opts[:data] == nil && opts != nil || opts[:data].length < 14 ||
				opts[:data].length < 15 && opts[:commandParameter] != nil)
			@data = []
			@data[0] = CmdIDs.assoc("REMOTE_COMMAND_REQUEST").last
			@data[1] = opts[:frameID]
			@data += addr64ToByteArray(opts[:destAddr])
			@data += addr16ToByteArray(opts[:netAddr])
			@data[12] = opts[:remoteCommandOpts]
			opts[:atCommand] = opts[:atCommand].bytes.to_a if opts[:atCommand].is_a? String
			opts[:atCommand].each_index{|i| @data.insert(13+i, opts[:atCommand][i])}
			@data = @data + opts[:commandParameter] if ((opts[:commandParameter] != nil) && (opts[:commandParameter].is_a? Array))
			@data.collect! {|x| if x == nil; 0 else x end }
		end
	end
	def getFrameID
		@data[1]
	end
	def getDestinationAddr
		@data[2..9]
	end
	def getNetAddr
		@data[10..11]
	end
	def getRemoteCommandOptions
		@data[12]
	end
	def getATCommand
		@data[13..14]
	end
	def getCommandParameter
		if @data.length > 14
			@data[15]
		else
			nil
		end
	end
end

class RemoteCommandResponse < APIFrame
	# opts hash arguments
	# ::data
	# ::frameID
	# ::sourceAddr
	# ::netAddr
	# ::atCommand
	# ::commandStatus
	# ::commandData
	def initialize(opts)
		super(opts[:data])
		if (opts[:data] == nil || opts[:data].length < 14 || opts[:data].length < 15 &&
			opts[:parameterValue] != nil)
			@data[0] = CmdIDs.assoc("REMOTE_COMMAND_RESPONSE").last
			@data[1] = opts[:frameID]
			@data += addr64ToByteArray(opts[:sourceAddr])
			@data += addr16ToByteArray(opts[:netAddr])
			opts[:atCommand] = opts[:atCommand].bytes.to_a if opts[:atCommand].is_a? String
			opts[:atCommand].each_index{|i| @data.insert(12+i, opts[:atCommand][i])}
			@data[14] = opts[:commandStatus]
			opts[:commandData] = opts[:commandData].bytes.to_a if opts[:commandData].is_a? String
			opts[:commandData].each_index{|i| @data.insert(12+i, opts[:commandData][i])}
			@data.collect! {|x| if x == nil; 0 else x end }
		end
	end
	def getFrameID
		@data[1]
	end
	def getSourceAddr
		@data[2..9]
	end
	def getNetAddr
		@data[10..11]
	end
	def getATCommand
		@data[12..13]
	end
	def getCommandStatus
		@data[14]
	end
	def getCommandData
		if @data.length > 14
			@data[15..-1]
		else
			nil
		end
	end
	def inspect
		puts "RemoteCommandResponse"
		puts "frameId=#{getFrameID}"
		puts "sourceAddr=#{getSourceAddr.pack('C*').unpack('H*').first}"
		puts "netAddr=#{getNetAddr.pack('C*').unpack('H*').first}"
		puts "atCommand=#{getATCommand.pack('C*')}"
		puts "commandStatus=#{getCommandStatus}"
		puts "commandData=#{getCommandData}"
	end
end

class NodeIdentificationIndicator < APIFrame
	# opts hash arguments
	# ::data
	# ::sourceAddr (64 bit)
	# ::sourceNetAddr (16 bit)
	# ::receiveOptions
	# ::destNetAddr (16 bit)
	# ::destAddr (64 bit)
	# ::nodeIdentifier
	# ::parentAddr (16 bit)
	# ::deviceType
	# ::sourceEvent
	# ::digiProfileId
	# ::manufacturerId
	def initialize(opts)
		super(opts[:data])
		if (opts[:data] != nil && opts[:data].length < 30)
			raise "Invalid data"
		end
		if (opts[:data] == nil || opts[:data].length < 30)
			@data[0] = CmdIDs.assoc("NODE_IDENTIFICATION_INDICATOR").last
			@data[1] = opts[:frameID]
			@data += addr64ToByteArray(opts[:sourceAddr])
			@data += addr16ToByteArray(opts[:sourceNetAddr])
			@data[11] = opts[:receiveOptions]
			@data += addr16ToByteArray(opts[:destNetAddr])
			@data += addr64ToByteArray(opts[:destAddr])
			opts[:nodeIdentifier] = opts[:nodeIdentifier].bytes.to_a if opts[:nodeIdentifier].is_a? String
			opts[:nodeIdentifier].each_index{|i| @data.insert(22+i, opts[:nodeIdentifier][i])}
			@data += addr16ToByteArray(opts[:parentAddr])
			@data[25+getNodeIdentifier.length] = opts[:deviceType]
			@data[26+getNodeIdentifier.length] = opts[:sourceEvent]
			opts[:digiProfileId].each_index{|i| @data.insert(27+i, opts[:digiProfileId][i])}
			opts[:manufacturerId].each_index{|i| @data.insert(29+i, opts[:manufacturerId][i])}
			@data.collect! {|x| if x == nil; 0 else x end }
		end
	end
	def getSourceAddr
		@data[1..8]
	end
	def getSourceNetAddr
		@data[9..10]
	end
	def wasBroadcast?
		if @data[11].to_i == 2
			true
		else
			false
		end
	end
	def getDestNetAddr
		@data[12..13]
	end
	def getDestAddr
		@data[14..21]
	end
	def getNodeIdentifier
		@data[22..@data.find_index(0)] # FIXME: find NULL string index
	end
	def getRemoteParent
		i = getNodeIdentifier.length
		@data[(22+i)..(22+i+2)]
	end
	def getDeviceType
		i = getNodeIdentifier.length
		@data[(25+i)]
	end
	def getSourceEvent
		i = getNodeIdentifier.length
		@data[(26+i)]
	end
	def getDigiProfileID
		i = getNodeIdentifier.length
		@data[(27+i)..(28+i)]
	end
	def getManufacturerID
		i = getNodeIdentifier.length
		@data[(29+i)..(30+i)]
	end
end

class ZigBeeTransmitRequest < APIFrame
	# opts hash arguments
	# ::data
	# ::frameID
	# ::destAddr
	# ::netAddr
	# ::broadcastRadius
	# ::options
	# ::payload
	def initialize(opts)
		super(opts[:data])
		if (opts[:data] == nil || opts[:data].length < 14)
			@data = []
			@data[0] = CmdIDs.assoc("ZIGBEE_TRANSMIT_REQUEST").last
			@data[1] = opts[:frameID]
			@data += addr64ToByteArray(opts[:destAddr])
			@data += addr16ToByteArray(opts[:netAddr])
			@data[12] = opts[:broadcastRadius]
			@data[13] = opts[:options]
			opts[:payload] = opts[:payload].bytes.to_a if opts[:payload].is_a? String
			opts[:payload].each_index{|i| @data.insert(14+i, opts[:payload][i])}
			@data.collect! {|x| if x == nil; 0 else x end }
		end
	end
	def getFrameID
		@data[1]
	end
	def getDestAddr
		@data[2..9]
	end
	def getNetAddr
		@data[10..11]
	end
	def getBroadcast
		@data[12]
	end
	def getOptions
		@data[13]
	end
	def getData
		if @data.length > 14
			@data[14..-1]
		else
			nil
		end
	end
	def inspect
		puts "ZigBeeTransmitRequest"
		puts "frameId=#{getFrameID}"
		puts "destAddr=#{getDestAddr.pack('C*').unpack('H*').first}"
		puts "netAddr=#{getNetAddr.pack('C*').unpack('H*').first}"
		puts "broadcast=#{getBroadcast}"
		puts "options=#{getOptions}"
		puts "data=#{getData}"
		puts "data(hex)=#{getData.pack('C*').unpack('H*').first}"
		puts "data(ascii)=#{getData.map{|n| n.chr}.reduce(:+)}"
	end
end

class ZigBeeExplicitAddressingCommand < APIFrame
	# opts hash arguments
	# ::data
	# ::frameID
	# ::destAddr
	# ::netAddr
	# ::sourceEndpoint
	# ::destEndpoint
	# ::clusterID
	# ::profileID
	# ::broadcastRadius
	# ::options
	# ::payload
	def initialize(opts)
		super(opts[:data])
		if (opts[:data] == nil || opts[:data].length < 20)
			@data = []
			@data[0] = CmdIDs.assoc("ZIGBEE_EXPLICIT_ADDRESSING_COMMAND").last
			@data[1] = opts[:frameID]
			@data += addr64ToByteArray(opts[:destAddr])
			@data += addr16ToByteArray(opts[:netAddr])
			@data[12] = opts[:sourceEndpoint]
			@data[13] = opts[:destEndpoint]
			@data += addr16ToByteArray(opts[:clusterID]) # method not meant for this purpose
			@data += addr16ToByteArray(opts[:profileID])
			@data[18] = opts[:broadcastRadius]
			@data[19] = opts[:options]
			opts[:payload] = opts[:payload].bytes.to_a if opts[:payload].is_a? String
			opts[:payload].each_index{|i| @data.insert(20+i, opts[:payload][i])}
			@data.collect! {|x| if x == nil; 0 else x end }
		end
	end
	def getFrameID
		@data[1]
	end
	def getDestAddr
		@data[2..9]
	end
	def getNetAddr
		@data[10..11]
	end
	def getSourceEndpoint
		@data[12]
	end
	def getDestinationEndpoint
		@data[13]
	end
	def getClusterID
		@data[14..15]
	end
	def getProfileID
		@data[16..17]
	end
	def getBroadcast
		@data[18]
	end
	def getOptions
		@data[19]
	end
	def getData
		if @data.length > 20
			@data[20..-1]
		else
			nil
		end
	end
	def inspect
		puts "ZigBeeExplicitAddressingCommand"
		puts "frameId=#{getFrameID}"
		puts "destAddr=#{getDestAddr.pack('C*').unpack('H*').first}"
		puts "netAddr=#{getNetAddr.pack('C*').unpack('H*').first}"
		puts "sourceEndpoint=#{getSourceEndpoint}"
		puts "destinationEndpoint=#{getDestinationEndpoint}"
		puts "clusterID=#{getClusterID.pack('C*').unpack('H*').first}"
		puts "profileID=#{getProfileID.pack('C*').unpack('H*').first}"
		puts "broadcast=#{getBroadcast}"
		puts "options=#{getOptions}"
		puts "data=#{getData}"
		#if ((getData.length > 0) && (getData.first.is_a? Fixnum))
		#	puts "data(hex)=#{getData.pack('C*').unpack('H*').first}"
		#	puts "data(ascii)=#{getData.map{|n| n.chr}.reduce(:+)}"
		#end
	end
end

class ZigBeeTransmitStatus < APIFrame
	# opts hash arguments
	# ::frameID
	# ::netAddr
	# ::transmitRetryCount
	# ::deliveryStatus
	# ::discoveryStatus
	def initialize(opts)
		super(opts[:data])
		if (opts[:data] == nil || opts[:data].length < 7)
			@data[0] = CmdIDs.assoc("ZIGBEE_TRANSMIT_STATUS").last
			@data[1] = opts[:frameID]
			@data += addr16ToByteArray(opts[:netAddr])
			@data[4] = opts[:transmitRetryCount]
			@data[5] = opts[:deliveryStatus]
			@data[6] = opts[:discoveryStatus]
		end
	end
	def getFrameID
		@data[1]
	end
	def getNetAddr
		@data[2..3]
	end
	def getTransmitRetryCount
		@data[4]
	end
	def getDeliveryStatus
		@data[5]
	end
	def getDiscoveryStatus
		@data[6]
	end
	def inspect
		puts "ZigBeeTransmitStatus"
		puts "frameId=#{getFrameID}"
		puts "netAddr=#{getNetAddr.pack('C*').unpack('H*').first}"
		puts "transmitRetryCount=#{getTransmitRetryCount}"
		puts "deliveryStatus=#{getDeliveryStatus}"
		puts "discoveryStatus=#{getDiscoveryStatus}"
	end
end

class ZigBeeReceivePacket < APIFrame
	# opts hash arguments
	# ::sourceAddr
	# ::netAddr
	# ::recvOpts
	# ::payload
	def initialize(opts)
		super(opts[:data])
		if (opts[:data] == nil || opts[:data].length < 7)
			@data[0] = CmdIDs.assoc("ZIGBEE_RECEIVE_PACKET").last
			@data += addr64ToByteArray(opts[:sourceAddr])
			@data += addr16ToByteArray(opts[:netAddr])
			@data[11] = opts[:recvOpts]
			opts[:payload] = opts[:payload].bytes.to_a if opts[:payload].is_a? String
			opts[:payload].each_index{|i| @data.insert(12+i, opts[:payload][i])}
			@data.collect! {|x| if x == nil; 0 else x end }
		end
	end
	def getSourceAddr
		@data[1..8]
	end
	def getNetAddr
		@data[9..10]
	end
	def getReceiveOptions
		@data[11]
	end
	def getData
		if @data.length > 11
			@data[12..-1]
		else
			nil
		end
	end
	def inspect
		puts "ZigBeeReceivePacket"
		puts "sourceAddr=#{getSourceAddr.pack('C*').unpack('H*').first}"
		puts "netAddr=#{getNetAddr.pack('C*').unpack('H*').first}"
		puts "options=#{getReceiveOptions}"
		puts "data=#{getData}"
		puts "data(hex)=#{getData.pack('C*').unpack('H*').first}"
		puts "data(ascii)=#{getData.map{|n| n.chr}.reduce(:+)}"
	end
end

class XBee
	include Observable
	Log = Logger.new(STDOUT)
	Log.level = Logger::DEBUG
	def initialize(serialPort)
		@serialPort = serialPort
	end
	def send(data)
		if data.is_a? UARTDataFrame
			Log.debug("Sending raw UART data frame as bytes=#{data.getBytes.unpack('C*')}, #{data.getBytes}")
			@serialPort.write(data.getBytes)
		elsif data.is_a? APIFrame
			Log.debug("Sending API frame")
			@serialPort.write(UARTDataFrame.new(data.getBytes).getBytes)
		elsif data.is_a? String
			Log.debug("Sending raw string #{data} as #{data.unpack('C*')}")
			@serialPort.write(data.unpack('C*'))
		else
			raise "Can not send #{data}, unknown datatype '#{data.class}'"
		end
	end
	def receive
		Thread.new {
			loop do
				Log.debug("reading UART data from xbee")
				if @serialPort.readbyte.object_id == 0x7E.object_id # API Frame Start Delimiter
					Log.debug("Start Delimiter found!")
					lengthMSB = @serialPort.readbyte
					lengthLSB = @serialPort.readbyte
					length = (lengthMSB << 8) + lengthLSB
					Log.debug("lengthMSB=#{lengthMSB},lengthLSB=#{lengthLSB},length=#{length}")
					data = []
					length.times do
						data << @serialPort.readbyte
					end
					Log.debug("read #{data.length} bytes")
					checksum = @serialPort.readbyte
					uartFrame = UARTDataFrame.new(data)
					Log.debug("read checksum=#{checksum}")
					if checksum.object_id == uartFrame.checksum.unpack('C').first.object_id
						Log.debug("notifying observers...")
						begin
							changed
							#Log.debug("observable marked as changed")
							notify_observers(getAPIFrame(uartFrame))
						rescue
							Log.warn("notifying observers failed!")
						end
					else
						Log.warn("invalid frame received!")
					end
				end
			end
		}
	end
	def getAPIFrame(uartFrame)
		apiFrame = APIFrame.new(uartFrame.getDataBytes)
		Log.debug("frame type=#{apiFrame.getType}")
		case apiFrame.getType
		when "AT_COMMAND"
			ATCommand.new(data: apiFrame.getBytes)
		when "AT_COMMAND_QUEUE_PARAMETER_VALUE"
			Log.warn("no implementation for this frame type")
			APIFrame.new(api.getBytes)
		when "ZIGBEE_TRANSMIT_REQUEST"
			ZigBeeTransmitRequest.new(data: api.getBytes)
		when "ZIGBEE_EXPLICIT_ADDRESSING_COMMAND"
			Log.warn("no implementation for this frame type")
			APIFrame.new(api.getBytes)
		when "REMOTE_COMMAND_REQUEST"
			RemoteCommandRequest.new(data: apiFrame.getBytes)
		when "CREATE_SOURCE_ROUTE"
			Log.warn("no implementation for this frame type")
			APIFrame.new(api.getBytes)
		when "AT_COMMAND_RESPONSE"
			ATCommandResponse.new(data: apiFrame.getBytes)
		when "MODEM_STATUS"
			ModemStatus.new(data: apiFrame.getBytes)
		when "ZIGBEE_TRANSMIT_STATUS"
			ZigBeeTransmitStatus.new(data: apiFrame.getBytes)
		when "ZIGBEE_RECEIVE_PACKET"
			Log.debug("returing new receive packet...")
			ZigBeeReceivePacket.new(data: apiFrame.getBytes)
		when "ZIGBEE_EXPLICIT_RX_INDICATOR"
			Log.warn("no implementation for this frame type")
			APIFrame.new(api.getBytes)
		when "ZIGBEE_IO_DATA_SAMPLE_RX_INDICATOR"
			ZigBeeIODataSampleRxIndicator.new(data: apiFrame.getBytes)
		when "XBEE_SENSOR_READ_INDICATOR"
			Log.warn("no implementation for this frame type")
			APIFrame.new(api.getBytes)
		when "NODE_IDENTIFICATION_INDICATOR"
			NodeIdentificationIndicator.new(data: apiFrame.getBytes)
		when "REMOTE_COMMAND_RESPONSE"
			RemoteCommandResponse.new(data: apiFrame.getBytes)
		when "OVER-THE-AIR_FIRMWARE_UPDATE_STATUS"
			Log.warn("no implementation for this frame type")
			APIFrame.new(api.getBytes)
		when "ROUTE_RECORD_INDICATOR"
			Log.warn("no implementation for this frame type")
			APIFrame.new(api.getBytes)
		when "MANY-TO-ONE_ROUTE_REQUEST_INDICATOR"
			Log.warn("no implementation for this frame type")
			APIFrame.new(api.getBytes)
		else
			Log.error("unknown API frame type")
			raise "Unknown API frame type"
		end
	end
end

class Node
	attr_accessor :addr, :netAddr, :identifier
	def getRemoteCommandRequest(atCommand, parameterValue)
		RemoteCommandRequest.new(
			frameID: 1,
			destAddr: addr,
			netAddr: netAddr,
			remoteCommandOpts: 0x20, # force APS encryption
			atCommand: atCommand,
			commandParameter: parameterValue)
	end
	def getZigBeeTransmitRequest(payloadData)
		ZigBeeTransmitRequest.new(
			frameID: 1,
			destAddr: addr,
			netAddr: netAddr,
			broadcastRadius: 0, # leave default
			options: 0x20, # force APS encryption
			payload: payloadData)
	end
	def getZigBeeExplicitAddressingCommand(
			sourceEndpoint,
			destEndpoint,
			clusterID,
			profileID,
			payloadData)
		ZigBeeExplicitAddressingCommand.new(
			frameID: 1,
			destAddr: addr,
			netAddr: netAddr,
			sourceEndpoint: sourceEndpoint,
			destEndpoint: destEndpoint,
			clusterID: clusterID,
			profileID: profileID,
			broadcastRadius: 0, # leave default
			options: 0x20, # force APS encryption
			payload: payloadData)
	end
end
