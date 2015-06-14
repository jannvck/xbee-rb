# xbee-rb
Minimal XBee library in Ruby

Set up a serial port instance and create the XBee:
```
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
```
xbee.send(RemoteCommandRequest.new(
	frameID: 1,
	destAddr: 0x000000000000FFFF,
	netAddr: 0xFFFE,
	remoteCommandOpts: 0,
	atCommand: "IS"))
```

Start receiving frames by using the observer pattern:
```
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