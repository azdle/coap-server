This repository holds the source code for a CoAP server written in Vala. It is
currently a work in progress.

From the RFC:

> The Constrained Application Protocol (CoAP) is a specialized web
> transfer protocol for use with constrained nodes and constrained
> (e.g., low-power, lossy) networks.  The nodes often have 8-bit
> microcontrollers with small amounts of ROM and RAM, while constrained
> networks such as 6LoWPAN often have high packet error rates and a
> typical throughput of 10s of kbit/s.  The protocol is designed for
> machine-to-machine (M2M) applications such as smart energy and
> building automation.

This source implements draft-18 of the protocol:
https://tools.ietf.org/html/draft-ietf-core-coap-18

# Status

The server is currently able to receive and decode CoAP messages, but it is
unable to respond to them and in fact can not send messages at all.

Incoming messages are output over stdout in the format:

    Compilation succeeded - 1 warning(s)
     ------------ COAP Message ------------ 
    Version:       CO_AP_MESSAGE_VERSION_COAP1
    Type:          CO_AP_MESSAGE_TYPE_NON
    Code:          CO_AP_MESSAGE_CODE_GET: 0.01
    Message_id:    4582
    Token Length:  0
    Options Count: 2
    Option Number: CO_AP_MESSAGE_OPTION_NUMBER_URI_PATH (11)
           Value:  .well-known
           Crit:   true
           Safe:   false
           CacheK: false
    Option Number: CO_AP_MESSAGE_OPTION_NUMBER_URI_PATH (11)
           Value:  core
           Crit:   true
           Safe:   false
           CacheK: false
    Payload: