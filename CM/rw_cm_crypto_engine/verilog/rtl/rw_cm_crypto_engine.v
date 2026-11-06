`default_nettype none
// Packet store and SLE CCM data path. Input payload octet 0 is word[7:0].
// nonce is in wire order, first nonce octet [103:96]. MIC is four octets.
// AAD is the one-octet zero associated-data field from SLE 9.3.1.3.
module rw_cm_crypto_engine(
 input wire clk,rst_n,
 input wire store_we,
 input wire [8:0] store_addr,
 input wire [31:0] store_data,
 input wire [3:0] store_be,
 input wire read_req,
 input wire [8:0] read_addr,
 output wire read_valid,
 output wire [31:0] read_data,
 input wire start,algorithm,decrypt,encrypt_payload,mic_enable,
 input wire [127:0] key,
 input wire [103:0] nonce,
 input wire [10:0] length,
 output wire busy,done,error,mic_ok,
 output wire [31:0] mic_value
);
 rw_cm_ccm_top ccm(.clk(clk),.rst_n(rst_n),.store_we(store_we),.store_addr(store_addr),.store_data(store_data),.store_be(store_be),.read_req(read_req),.read_addr(read_addr),.read_valid(read_valid),.read_data(read_data),.start(start),.algorithm(algorithm),.decrypt(decrypt),.encrypt_payload(encrypt_payload),.mic_enable(mic_enable),.key(key),.nonce(nonce),.length(length),.busy(busy),.done(done),.error(error),.mic_ok(mic_ok),.mic_value(mic_value));
endmodule
`default_nettype wire
