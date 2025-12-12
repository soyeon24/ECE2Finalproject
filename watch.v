module watch ( 
    clk, rst, seg_data, seg_com,
    load_time, load_value, 
    o_h_ten, o_h_one, o_m_ten, o_m_one, o_s_ten, o_s_one,
    day_tick // [NEW] 날짜 변경 신호 포트 추가
);
    input clk; input rst;
    input load_time; input [23:0] load_value;
    
    output [7:0] seg_data; output [7:0] seg_com;
    output [3:0] o_h_ten, o_h_one, o_m_ten, o_m_one, o_s_ten, o_s_one;
    output reg day_tick; // [NEW] 출력 선언

    reg [9:0] ms_cnt;
    reg [5:0] h_ten,h_one,m_ten, m_one, s_ten, s_one;
    wire [7:0] seg_h_ten, seg_h_one, seg_m_ten, seg_m_one, seg_s_ten, seg_s_one;
    reg [2:0] s_cnt; 
    reg [7:0] seg_data_reg, seg_com_reg;  
    
    assign seg_data = seg_data_reg; assign seg_com = seg_com_reg;

    always @(posedge rst or posedge clk) begin
        if (rst) begin
            ms_cnt <= 0;
            h_ten <= 0; h_one <= 0; m_ten <= 0; m_one <= 0; s_ten <= 0; s_one <= 0;
            day_tick <= 0; // [NEW] 초기화
        end 
        else if (load_time) begin 
            ms_cnt <= 0; day_tick <= 0;
            h_ten <= load_value[23:20]; h_one <= load_value[19:16];
            m_ten <= load_value[15:12]; m_one <= load_value[11:8];
            s_ten <= load_value[7:4];   s_one <= load_value[3:0];
        end
        else begin
            day_tick <= 0; // [NEW] 평소에는 0 (펄스 신호)
            
            if (ms_cnt < 999) ms_cnt <= ms_cnt + 1;
            else begin
                ms_cnt <= 0;
                if (s_one < 9) s_one <= s_one + 1;
                else begin
                    s_one <= 0;
                    if (s_ten < 5) s_ten <= s_ten + 1;
                    else begin
                        s_ten <= 0;
                        if (m_one < 9) m_one <= m_one + 1;
                        else begin
                            m_one <= 0;
                            if (m_ten < 5) m_ten <= m_ten + 1;
                            else begin // 59분 -> 00분 넘어갈 때
                                m_ten <= 0;
                                // [시간 변경 로직 수정]
                                if (h_ten == 2 && h_one == 3) begin
                                    // 23시 -> 00시 (하루 지남!)
                                    h_ten <= 0; h_one <= 0;
                                    day_tick <= 1; // [NEW] 신호 발생!
                                end 
                                else if (h_one < 9) begin
                                    h_one <= h_one + 1;
                                end
                                else begin // h_one == 9
                                    h_one <= 0; h_ten <= h_ten + 1;
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    // ... (디코더 및 디스플레이 부분은 기존과 동일하므로 생략, 그대로 두세요) ...
    seg_decode u4 (m_ten, seg_m_ten);
    seg_decode u5 (m_one, seg_m_one);
    seg_decode u6 (s_ten, seg_s_ten);
    seg_decode u7 (s_one, seg_s_one);
    seg_decode u8 (h_ten, seg_h_ten);
    seg_decode u9 (h_one, seg_h_one);

    always @(posedge clk) begin
        if (rst) s_cnt <= 0;
        else if(s_cnt >= 5) s_cnt <= 0; 
        else s_cnt <= s_cnt + 1;
    end
    
    always @(posedge clk) begin
        if (rst) seg_com_reg <= 8'b1111_1111;
        else case (s_cnt)
            3'd0: seg_com_reg <= 8'b1111_1110;
            3'd1: seg_com_reg <= 8'b1111_1101; 
            3'd2: seg_com_reg <= 8'b1111_1011; 
            3'd3: seg_com_reg <= 8'b1111_0111; 
            3'd4: seg_com_reg <= 8'b1110_1111; 
            3'd5: seg_com_reg <= 8'b1101_1111;
            default: seg_com_reg <= 8'b1111_1111;
        endcase
    end
    
    always @(posedge clk) begin
        if (rst) seg_data_reg <= 8'b0000_0000;
        else case (s_cnt)
            3'd0: seg_data_reg <= seg_s_one;
            3'd1: seg_data_reg <= seg_s_ten;
            3'd2: seg_data_reg <= seg_m_one;
            3'd3: seg_data_reg <= seg_m_ten;
            3'd4: seg_data_reg <= seg_h_one;
            3'd5: seg_data_reg <= seg_h_ten;
            default: seg_data_reg <= 8'b0000_0000;
        endcase
    end
    
    assign o_h_ten = h_ten; assign o_h_one = h_one;
    assign o_m_ten = m_ten; assign o_m_one = m_one;
    assign o_s_ten = s_ten; assign o_s_one = s_one;

endmodule