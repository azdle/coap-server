
public errordomain CoAPError {
    UNKNOWN_VERSION,
    UNKNOWN_CODE,
    MALFORMED_MESSAGE,
    OPTION_ORDER
}

public class CoAP.Message : GLib.Object {

    public struct Option {
        public OptionNumber number;
        public uint8[] value;

        public bool critical{
            get { return (number & 0x01) == 1; }
        }
        public bool elective{
            get { return !critical; }
        }

        public bool unsafe{
            get { return (number & 0x02) == 2; }
        }
        public bool safe_to_forward{
            get { return !unsafe; }
        }

        public bool no_cache_key{
            get { return (number & 0x01) == 1; }
        }
        public bool cache_key{
            get { return !no_cache_key; }
        }

    }

    public enum Version{
        COAP1 = 1,
    }

    public enum Type{
        CON = 0,
        NON = 1,
        ACK = 2,
        RST = 3,
    }

    public enum Code{
        EMPTY = 0x00,
        GET = 0x01,
        POST = 0x02,
        PUT = 0x03,
        DELETE = 0x04,
        CREATED = 0x41,
        DELETED = 0x42,
        VALID = 0x43,
        CHANGED = 0x44,
        CONTENT = 0x45,
        BAD_REQUEST = 0x80,
        UNAUTHORIZED = 0x81,
        BAD_OPTION = 0x82,
        FORBIDDEN = 0x83,
        NOT_FOUND = 0x84,
        METHOD_NOT_ALLOWED = 0x85,
        NOT_ACCEPTABLE = 0x86,
        PRECONDITION_FAILED = 0x8c,
        REQUEST_ENTITY_TOO_LARGE = 0x8d,
        UNSUPPORTED_CONTENT_FORMAT = 0x8f,
        INTERNAL_SERVER_ERROR = 0xa0,
        NOT_IMPLEMENTED = 0xa1,
        BAD_GATEWAY = 0xa2,
        SERVICE_UNAVAILABLE = 0xa3,
        GATEWAY_TIMEOUT = 0xa4,
        PROXYING_NOT_SUPPORTED = 0xa5,
    }

    public enum CodeClass{
        REQUEST = 0,
        SUCCESS = 2,
        CLIENT_ERROR = 4,
        SERVER_ERROR = 5,
    }

    public enum OptionNumber{
        IF_MATCH = 1,
        URI_HOST = 2,
        ETAG = 4,
        IF_NONE_MATCH = 5,
        URI_PORT = 7,
        LOCATION_PATH = 8,
        URI_PATH = 11,
        CONTENT_FORMAT = 12,
        MAX_AGE = 14,
        URI_QUERY = 15,
        ACCEPT = 17,
        LOCATION_QUERY = 20,
        PROXY_URI = 35,
        PROXY_SCHEME = 39,
        SIZE1 = 60;
    }

    //TODO: Figure out if it's possible to have a custom uint8 type that
    //      will be able to limit the range to 00 to 31 (dec) ofr CodeDetail.

    private uint8[] payload;


    public Version version = Version.COAP1;

    public Type _type = Type.NON;

    public Code code{
        get { return (Code) (code_class << 5) + code_detail; }
        set { code_class = (CodeClass) value >> 5; code_detail = (uint8) value & 0x1f; }
    }

    public CodeClass code_class = CodeClass.REQUEST;

    public uint8 code_detail = 0;

    public uint16 message_id = 0;

    public uint8[] token;

    private Option[] options = {};

    public Message() {

    }

    public Message.from_uint8(uint8[] datagram, size_t length = datagram.length) throws CoAPError {
        size_t token_length = 0;
        size_t datagram_index = 0;
        uint16 option_number = 0;
        bool has_payload = false;


        version = (Version) datagram[0] >> 6;
        _type = (Type) (datagram[0] >> 4) & 0x03;
        token_length = datagram[0] & 0x0f;
        code = (Code) datagram[1];
        message_id = (datagram[2] << 8) | datagram[3];

        if(token_length > 0 && token_length <= 8){
            token = datagram[4:4+token_length];
        }else if(token_length > 8){
            throw new CoAPError.MALFORMED_MESSAGE(
                "Token length must be less than or equal to 8 bytes.\n");
        }

        datagram_index = 4 + token_length;

        while(datagram_index < length){

            if(datagram[datagram_index] == 0xff){
                // Payload Marker
                has_payload = true;
                datagram_index += 1;
                break;
            }
            uint8 short_option_delta =  datagram[datagram_index] >> 4;
            uint8 short_option_length = datagram[datagram_index] & 0x0f;
            uint16 option_length = 0;

            datagram_index += 1;

            if(short_option_delta > 12){
                if(short_option_delta == 13){
                    option_number += datagram[datagram_index] + 13;
                    datagram_index += 1;
                }else if(short_option_delta == 14){
                    option_number += (datagram[datagram_index] << 8) +
                        datagram[datagram_index + 1] + 269;
                    datagram_index += 2;
                }else if(short_option_delta == 15){
                    throw new CoAPError.MALFORMED_MESSAGE(
                        "Option delta is 0xf, but not payload marker.\n");  
                }
            }else{
                option_number += short_option_delta;
            }

            if(short_option_length > 12){
                if(short_option_length == 13){
                    option_length = datagram[datagram_index] + 13;
                    datagram_index += 1;
                }else if(short_option_length == 14){
                    option_length = (datagram[datagram_index] << 8) |
                        datagram[datagram_index + 1] + 269;
                    datagram_index += 2;
                }else if(short_option_length == 15){
                    throw new CoAPError.MALFORMED_MESSAGE(
                        "Option length is 0xf, but not payload marker.\n");  
                }
            }else{
                option_length = short_option_length;
            }


            options += Option(){
                number = (OptionNumber)option_number,
                value = datagram[datagram_index:datagram_index+option_length] 
            };

            datagram_index += option_length;
        }

        if(datagram_index < length){
            if(has_payload){
                payload = datagram[datagram_index:length];
            }else{
                throw new CoAPError.MALFORMED_MESSAGE(
                    "Message has payload marker, but no payload.\n"); 
            }
        }

    }

    public uint8[] create_datagram() throws CoAPError {
        uint8[] datagram = new uint8[1501]; // 1500 + 1 for NULL Terminator
        datagram[1500] = 0; // Just in Case, Should Not be Needed

        size_t datagram_index = 0;

        datagram[datagram_index++] = (this.version << 6) | (this._type << 4) | (this.token.length);
        datagram[datagram_index++] = this.code;
        datagram[datagram_index++] = (uint8) (message_id >> 8);
        datagram[datagram_index++] = (uint8) (message_id & 0xff);

        if(this.token.length != 0){
            foreach(uint8 t in token){
                datagram[datagram_index++] = t;
            }
        }

        //TODO: Sort Options

        uint16 last_option_number = 0;

        foreach(Option o in options){
            if(o.number < last_option_number){
                throw new CoAPError.OPTION_ORDER("Options must be sorted by their option number.");
            }

            uint8* option_start_pointer = &datagram[datagram_index];

            if(o.number - last_option_number < 13){
                datagram[datagram_index++] = o.number << 4;
            }else if(o.number -last_option_number < 269){
                datagram[datagram_index++] = 13 << 4;
                datagram[datagram_index++] = o.number - 13;
            }else{
                datagram[datagram_index++] = 14 << 4;
                datagram[datagram_index++] = (o.number - 269) >> 8;
                datagram[datagram_index++] = (o.number - 269) & 0xff;
            }

            if(o.value.length - last_option_number < 13){
                *option_start_pointer |= o.value.length;
            }else if(o.value.length -last_option_number < 269){
                *option_start_pointer |= 13;
                datagram[datagram_index++] = (uint8) o.value.length - 13;
            }else{
                *option_start_pointer |= 14;
                datagram[datagram_index++] = (uint8) (o.value.length - 269) >> 8;
                datagram[datagram_index++] = (uint8) (o.value.length - 269) & 0xff;
            }

            foreach(uint8 b in o.value){
                datagram[datagram_index++] = b;
            }
        }

        foreach(uint8 b in payload){
            if(datagram_index >= 1500){
                throw new CoAPError.MALFORMED_MESSAGE("Total message length is longer than 1500 bytes.");
            }

            datagram[datagram_index++] = b;
        }

        datagram.length = (int) datagram_index;

        return datagram;
    }

    public string to_string() {
        var builder = new StringBuilder ();
        builder.append       (" ------------ COAP Message ------------ \n");
        builder.append_printf("Version:       %s\n", version.to_string());
        builder.append_printf("Type:          %s\n", _type.to_string());
        builder.append_printf("Code:          %s: %i.%02i\n", code.to_string(), code_class, code_detail);
        builder.append_printf("Message_id:    %x\n", message_id);
        builder.append_printf("Token Length:  %i\n", token.length);
        builder.append_printf("Options Count: %i\n", options.length);
        foreach(Option option in options){
            builder.append_printf("Option Number: %s (%u)\n", option.number.to_string(), option.number);
            builder.append_printf("       Value:  %*.*s\n", option.value.length, option.value.length, (string) option.value);
            builder.append_printf("       Crit:   %s\n", option.critical.to_string());
            builder.append_printf("       Safe:   %s\n", option.safe_to_forward.to_string());
            builder.append_printf("       CacheK: %s\n", option.cache_key.to_string());
        }
        builder.append_printf("Payload: %*.*s\n", payload.length, payload.length, (string)payload);

        return builder.str;
    }
}