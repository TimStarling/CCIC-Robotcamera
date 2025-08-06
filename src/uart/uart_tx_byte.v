// 串口发送指定位宽数据
module uart_tx_byte #(
    parameter               SEND_WIDTH  =   19
)
(
    input  wire                     sys_clk,
    input  wire                     sys_rst_n,

    input  wire                     tx_en,
    input  wire [SEND_WIDTH-1:0]    tx_data,

    output wire                     uart_tx,
    output reg                      tx_done
);

    reg                             tx_byte_en;
    reg     [7:0]                   tx_byte;
    wire                            tx_byte_done;
    uart_byte_tx u_uart_byte_tx(
        .sys_clk                    (sys_clk        ),
        .sys_rst_n                  (sys_rst_n      ),
        .tx_en                      (tx_byte_en     ),
        .tx_data                    (tx_byte        ),
        .uart_tx                    (uart_tx        ),
        .tx_done                    (tx_byte_done   )
    );
    

    // 发送字节计数
    localparam                      TX_CNT_MAX  =   (SEND_WIDTH + 8 - 1) / 8;   // 除8向上取整
    reg     [7:0]                   tx_cnt;

    // 单字节发送使能
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            tx_byte_en              <=  1'b0;
        end
        // 外部使能有效且没有字节正在发送
        else if(tx_en && tx_done) begin
            tx_byte_en              <=  1'b1;
        end
        // 发送完全部字节
        else if(tx_cnt >= TX_CNT_MAX - 1) begin
            tx_byte_en              <=  1'b0;
        end
        else begin
            tx_byte_en              <=  tx_byte_en;
        end
    end

    // 发送字节计数
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            tx_cnt                  <=  8'b0;
            tx_done                 <=  1'b1;
        end
        else if(tx_en && tx_done) begin
            tx_cnt                  <=  8'b0;
            tx_done                 <=  1'b0;
        end
        else if(tx_byte_done) begin
            if(tx_cnt >= TX_CNT_MAX - 1) begin
                tx_cnt              <=  8'b0;
                tx_done             <=  1'b1;
            end
            else begin
                tx_cnt              <=  tx_cnt + 1'b1;
                tx_done             <=  1'b0;
            end
        end
        else begin
            tx_cnt                  <=  tx_cnt;
            tx_done                 <=  tx_done;
        end
    end

    // 待发送数据
    reg     [TX_CNT_MAX*8-1:0]      tx_data_r;
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            tx_data_r               <=  'b0;
        end
        // 开始时锁存数据，补零扩充到位宽为8的倍数
        else if(tx_en && tx_done) begin
            tx_data_r               <=  {{(TX_CNT_MAX*8-SEND_WIDTH){1'b0}}, tx_data};
        end
        // 每发送完一个字节，左移8位
        else if(tx_byte_done) begin
            tx_data_r               <=  {8'b0, tx_data_r[TX_CNT_MAX*8-1:8]};
        end
        else begin
            tx_data_r               <=  tx_data_r;
        end
    end

    // 待发送字节数据
    always @(*) begin
        tx_byte                     =   tx_data_r[7:0];
    end

endmodule //uart_tx