int main () {
    try {

        var socket = new Socket (SocketFamily.IPV4,
                                 SocketType.DATAGRAM, 
                                 SocketProtocol.UDP);
        var sa = new InetSocketAddress (new InetAddress.loopback (SocketFamily.IPV4),
                                        5683);
        socket.bind (sa, true);

        var source = socket.create_source (IOCondition.IN);
        source.set_callback ((s, cond) => {
            try {
                CoAP.Message message;
                uint8[] buffer = new uint8[2048];
                size_t read = s.receive (buffer);
                buffer[read] = 0; // null-terminate string
                message = new CoAP.Message.from_uint8(buffer, read);
                print(message.to_string());
                //print ("Got %ld bytes of data: \n", (long) read);
                //hex_dump(buffer, read);
            } catch (Error e) {
                stderr.printf (e.message);
            }
            return true;
        });
        source.attach (MainContext.default ());

        new MainLoop ().run ();
        
    } catch (Error e) {
        stderr.printf (e.message);
        return 1;
    }
    
    return 0;
}

void hex_dump(uint8[] buffer, size_t length = buffer.length){
    for(size_t i = 0; i < length; i += 16){
        stdout.printf("%04zu:",  i);
        for(size_t j = 0; j < 16; j += 1){

            if(j < length - i){
                stdout.printf(" %02x", buffer[i+j]);
            }else{
                stdout.printf("   ");
            }
        }
        stdout.printf("    ");
        for(size_t j = 0; j < 16; j += 1){

            if(j < length - i){
                if((buffer[i+j] >= 0x20 && buffer[i+j] <=0x7e)){
                    stdout.printf("%c", (char) buffer[i+j]);
                }else{
                    stdout.printf("%1.1s", "·");
                }
            }
        }
        stdout.printf("\n");
    }
}