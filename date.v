module date(
    input clk,
    input rst,
    input [9:0] sw_num,
    input day_tick,          // [NEW] 하루 지남 신호
    output [7:0] seg_data,
    output [7:0] seg_com
);
    reg [3:0] y_ten, y_one;
    reg [3:0] m_ten, m_one;
    reg [3:0] d_ten, d_one;

    parameter SET_Y_TEN = 0, SET_Y_ONE = 1, SET_M_TEN = 2, SET_M_ONE = 3, 
              SET_D_TEN = 4, SET_D_ONE = 5, VIEW = 6;
    reg [2:0] state;

    reg [9:0] sw_prev;
    wire [9:0] sw_rise = sw_num & ~sw_prev;
    reg [3:0] key_val;
    reg key_pressed;
    integer i;

    // 현재 월의 마지막 날짜 계산 (윤년 제외 28일 고정)
    reg [4:0] days_in_month;
    wire [4:0] cur_month = m_ten * 10 + m_one;
    wire [4:0] cur_day   = d_ten * 10 + d_one;

    always @(*) begin
        case(cur_month)
            2: days_in_month = 28;
            4, 6, 9, 11: days_in_month = 30;
            default: days_in_month = 31;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) sw_prev <= 0;
        else sw_prev <= sw_num;
    end

    always @(*) begin
        key_val = 0; key_pressed = 0;
        for(i=0; i<10; i=i+1) if(sw_rise[i]) begin key_val = i; key_pressed = 1; end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= SET_Y_TEN;
            y_ten <= 2; y_one <= 5; m_ten <= 1; m_one <= 2; d_ten <= 1; d_one <= 2;
        end 
        else if (key_pressed) begin
            // [수동 설정 로직]
            case (state)
                SET_Y_TEN: begin y_ten <= key_val; state <= SET_Y_ONE; end
                SET_Y_ONE: begin y_one <= key_val; state <= SET_M_TEN; end
                SET_M_TEN: begin m_ten <= (key_val > 1) ? 1 : key_val; state <= SET_M_ONE; end
                SET_M_ONE: begin m_one <= key_val; state <= SET_D_TEN; end
                SET_D_TEN: begin d_ten <= (key_val > 3) ? 3 : key_val; state <= SET_D_ONE; end
                SET_D_ONE: begin d_one <= key_val; state <= VIEW; end
                VIEW: begin y_ten <= key_val; state <= SET_Y_ONE; end
            endcase
        end
        else if (state == VIEW && day_tick) begin
            // [NEW] 자동 날짜 변경 로직 (24시 지남)
            if (cur_day < days_in_month) begin
                // 단순히 일 증가
                if (d_one < 9) d_one <= d_one + 1;
                else begin d_one <= 0; d_ten <= d_ten + 1; end
            end 
            else begin
                // 월 넘어감 (1일로 초기화)
                d_ten <= 0; d_one <= 1;
                if (cur_month < 12) begin
                    if (m_one < 9) m_one <= m_one + 1;
                    else begin m_one <= 0; m_ten <= m_ten + 1; end
                end 
                else begin
                    // 연도 넘어감 (1월로 초기화)
                    m_ten <= 0; m_one <= 1;
                    if (y_one < 9) y_one <= y_one + 1;
                    else begin y_one <= 0; y_ten <= y_ten + 1; end
                end
            end
        end
    end

    // ... (디스플레이 로직은 이전과 동일) ...
    wire [7:0] dec_y_ten, dec_y_one, dec_m_ten, dec_m_one, dec_d_ten, dec_d_one;
    seg_decode u0 (y_ten, dec_y_ten); seg_decode u1 (y_one, dec_y_one);
    seg_decode u2 (m_ten, dec_m_ten); seg_decode u3 (m_one, dec_m_one);
    seg_decode u4 (d_ten, dec_d_ten); seg_decode u5 (d_one, dec_d_one);

    reg [2:0] s_cnt; reg [7:0] seg_data_reg, seg_com_reg;
    assign seg_data = seg_data_reg; assign seg_com  = seg_com_reg;

    always @(posedge clk) begin
        if(rst) s_cnt <= 0;
        else if(s_cnt >= 5) s_cnt <= 0;
        else s_cnt <= s_cnt + 1;
    end

    always @(posedge clk) begin
        if(rst) begin seg_com_reg <= 8'b1111_1111; seg_data_reg <= 0; end 
        else begin
            case(s_cnt)
                3'd0: begin seg_com_reg <= 8'b1111_1110; seg_data_reg <= dec_d_one; end
                3'd1: begin seg_com_reg <= 8'b1111_1101; seg_data_reg <= dec_d_ten; end
                3'd2: begin seg_com_reg <= 8'b1111_1011; seg_data_reg <= dec_m_one; end
                3'd3: begin seg_com_reg <= 8'b1111_0111; seg_data_reg <= dec_m_ten; end
                3'd4: begin seg_com_reg <= 8'b1110_1111; seg_data_reg <= dec_y_one; end
                3'd5: begin seg_com_reg <= 8'b1101_1111; seg_data_reg <= dec_y_ten; end
                default: seg_com_reg <= 8'b1111_1111;
            endcase
        end
    end
endmodule