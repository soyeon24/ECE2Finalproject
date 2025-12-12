module world_time(
    input clk,
    input rst,
    // watch 모듈에서 받아올 한국 시간 (KST)
    input [3:0] kst_h_ten, kst_h_one,
    input [3:0] kst_m_ten, kst_m_one,
    input [3:0] kst_s_ten, kst_s_one,
    
    output [7:0] seg_data,
    output [7:0] seg_com
);

    // 1. 시간 변환 로직 (KST -> UTC)
    // KST = UTC + 9  =>  UTC = KST - 9
    
    reg [4:0] kst_hour_val; // 계산을 위해 합친 시간 값 (0~23)
    reg [4:0] utc_hour_val; // 변환된 UTC 시간 값
    
    reg [3:0] utc_h_ten, utc_h_one; // 7세그먼트용 분리된 값

    always @(*) begin
        // 십의 자리와 일의 자리를 합쳐서 정수로 만듦
        kst_hour_val = (kst_h_ten * 10) + kst_h_one;
        
        // 9시간 빼기
        if (kst_hour_val >= 9) begin
            utc_hour_val = kst_hour_val - 9;
        end else begin
            // 0시~8시인 경우 하루 전으로 돌아감 (예: 02시 - 9시간 = 전날 17시)
            utc_hour_val = kst_hour_val + 24 - 9; 
        end

        // 다시 십의 자리와 일의 자리로 분리
        utc_h_ten = utc_hour_val / 10;
        utc_h_one = utc_hour_val % 10;
    end

    // 2. 디스플레이 로직 (watch.v와 동일한 구조)
    wire [7:0] seg_h_ten, seg_h_one, seg_m_ten, seg_m_one, seg_s_ten, seg_s_one;
    reg [2:0] s_cnt;
    reg [7:0] seg_data_reg, seg_com_reg;

    assign seg_data = seg_data_reg;
    assign seg_com  = seg_com_reg;

    // 디코더 연결 (시간은 변환된 UTC 사용, 분/초는 KST 그대로 사용)
    seg_decode u_h_t (utc_h_ten, seg_h_ten);
    seg_decode u_h_o (utc_h_one, seg_h_one);
    seg_decode u_m_t (kst_m_ten, seg_m_ten);
    seg_decode u_m_o (kst_m_one, seg_m_one);
    seg_decode u_s_t (kst_s_ten, seg_s_ten);
    seg_decode u_s_o (kst_s_one, seg_s_one);

    // 스캔 카운터
    always @(posedge clk) begin
        if (rst) s_cnt <= 0;
        else if (s_cnt >= 5) s_cnt <= 0;
        else s_cnt <= s_cnt + 1;
    end

    // 출력 선택
    always @(posedge clk) begin
        if (rst) begin
            seg_com_reg <= 8'b1111_1111;
            seg_data_reg <= 8'b0000_0000;
        end else begin
            case (s_cnt)
                3'd0: begin seg_com_reg <= 8'b1111_1110; seg_data_reg <= seg_s_one; end
                3'd1: begin seg_com_reg <= 8'b1111_1101; seg_data_reg <= seg_s_ten; end
                3'd2: begin seg_com_reg <= 8'b1111_1011; seg_data_reg <= seg_m_one; end
                3'd3: begin seg_com_reg <= 8'b1111_0111; seg_data_reg <= seg_m_ten; end
                3'd4: begin seg_com_reg <= 8'b1110_1111; seg_data_reg <= seg_h_one; end // UTC 적용됨
                3'd5: begin seg_com_reg <= 8'b1101_1111; seg_data_reg <= seg_h_ten; end // UTC 적용됨
                default: seg_com_reg <= 8'b1111_1111;
            endcase
        end
    end

endmodule