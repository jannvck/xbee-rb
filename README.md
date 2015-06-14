# xbee-rb
Minimal XBee®/XBee-PRO® ZB library in Ruby.
Host XBee is required to run in API mode.
Not all API frames have been implemented but this library provides
the means to send and receive data.

Set up a serial port instance and create the XBee:
```ruby
# access serial port
sp = SerialPort.new(
	"/dev/ttyAMA0", # port
	9600, # baud                                                 
	8, # data_bits
	1, # stop_bits
	SerialPort::NONE) # parity
sp.flow_control = SerialPort::NONE
sp.read_timeout=0
# create an XBee instance
xbee = XBee.new(sp)
```


Send an AT Command frame to sample IO data:
```ruby
xbee.send(RemoteCommandRequest.new(
	frameID: 1,
	destAddr: 0x000000000000FFFF,
	netAddr: 0xFFFE,
	remoteCommandOpts: 0,
	atCommand: "IS"))
```

Start receiving frames by using the observer pattern:
```ruby
class Messages
	def initialize(xbee)
		@xbee = xbee
		@xbee.add_observer(self)
	end
 	def update(frame) # will be called when a frame is received
 		frame.getBytes
 	end
end
xbee.receive # start receiving
```

Implemented API Frames as corresponding class names:

* ATCommand
* ATCommandResponse
* ZigBeeIODataSampleRxIndicator
* ModemStatus
* RemoteCommandRequest
* RemoteCommandResponse
* NodeIdentificationIndicator
* ZigBeeTransmitRequest
* ZigBeeExplicitAddressingCommand
* ZigBeeTransmitStatus
* ZigBeeReceivePacket