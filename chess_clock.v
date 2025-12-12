module chess_clock(
    input clk,              // 시스템 클럭 (1kHz)
    input rst,
    input btn_left,         // 왼쪽 플레이어 버튼 (*)
    input btn_right,        // 오른쪽 플레이어 버튼 (#)
    input [9:0] sw_num,     // 초기 시간 설정용 (SW0:1분, SW1:3분, SW2:5분, SW3:10분)

    output [7:0] seg_data,
    output [7:0] seg_com,
    output reg [1:0] game_state // 0:준비, 1:A턴, 2:B턴, 3:종료
);

    // -----------------------------------------------------
    // 1. 상태 및 시간 변수 정의
    // -----------------------------------------------------
    parameter IDLE = 0, TURN_A = 1, TURN_B = 2, OVER = 3;
    
    // 시간은 초 단위로 저장 (최대 9분 59초 = 599초)
    reg [9:0] time_a; // 왼쪽 플레이어 남은 시간
    reg [9:0] time_b; // 오른쪽 플레이어 남은 시간
    
    reg winner; // 0: A승(B시간초과), 1: B승(A시간초과)

    // 버튼 엣지 검출
    reg btn_l_prev, btn_r_prev;
    wire l_click = btn_left && !btn_l_prev;
    wire r_click = btn_right && !btn_r_prev;

    always @(posedge clk) begin
        if(rst) begin btn_l_prev <= 0; btn_r_prev <= 0; end
        else begin btn_l_prev <= btn_left; btn_r_prev <= btn_right; end
    end

    // 1초 생성기 (1kHz -> 1Hz)
    reg [9:0] ms_cnt;
    wire tick_1sec = (ms_cnt >= 999);

    always @(posedge clk or posedge rst) begin
        if (rst) ms_cnt <= 0;
        else if (game_state == TURN_A || game_state == TURN_B) begin
            if (tick_1sec) ms_cnt <= 0;
            else ms_cnt <= ms_cnt + 1;
        end
    end

    // -----------------------------------------------------
    // 2. 메인 로직 (상태 머신)
    // -----------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            game_state <= IDLE;
            time_a <= 300; // 기본 5분
            time_b <= 300;
            winner <= 0;
        end else begin
            case (game_state)
                IDLE: begin
                    // 시간 설정 (스위치)
                    if (sw_num[0]) begin time_a <= 60;  time_b <= 60;  end // 1분
                    else if (sw_num[1]) begin time_a <= 180; time_b <= 180; end // 3분
                    else if (sw_num[2]) begin time_a <= 300; time_b <= 300; end // 5분
                    else if (sw_num[3]) begin time_a <= 600; time_b <= 600; end // 10분

                    // 게임 시작: 아무 버튼이나 누르면 상대방 턴으로 시작
                    if (l_click) game_state <= TURN_B; // 내가 누르면 상대 턴 시작
                    else if (r_click) game_state <= TURN_A;
                end

                TURN_A: begin
                    // A의 턴: A 시간이 줄어듦
                    if (tick_1sec) begin
                        if (time_a > 0) time_a <= time_a - 1;
                        else begin
                            game_state <= OVER; // A 시간 초과 -> B 승리
                            winner <= 1; 
                        end
                    end
                    // A가 버튼을 누르면 -> 턴 종료 (B 턴으로)
                    if (l_click) game_state <= TURN_B;
                end

                TURN_B: begin
                    // B의 턴: B 시간이 줄어듦
                    if (tick_1sec) begin
                        if (time_b > 0) time_b <= time_b - 1;
                        else begin
                            game_state <= OVER; // B 시간 초과 -> A 승리
                            winner <= 0;
                        end
                    end
                    // B가 버튼을 누르면 -> 턴 종료 (A 턴으로)
                    if (r_click) game_state <= TURN_A;
                end

                OVER: begin
                    // 종료 상태: 리셋 전까지 대기
                    // (재시작하려면 rst 필요)
                end
            endcase
        end
    end

    // -----------------------------------------------------
    // 3. 디스플레이 데이터 준비 (3자리 분리)
    // -----------------------------------------------------
    // 표시 형식: M : SS (분 1자리, 초 2자리)
    
    // Player A (Left)
    wire [3:0] a_min = time_a / 60;
    wire [3:0] a_s_ten = (time_a % 60) / 10;
    wire [3:0] a_s_one = (time_a % 60) % 10;

    // Player B (Right)
    wire [3:0] b_min = time_b / 60;
    wire [3:0] b_s_ten = (time_b % 60) / 10;
    wire [3:0] b_s_one = (time_b % 60) % 10;

    wire [7:0] dec_a_m, dec_a_st, dec_a_so;
    wire [7:0] dec_b_m, dec_b_st, dec_b_so;

    seg_decode u1(a_min, dec_a_m);   seg_decode u2(a_s_ten, dec_a_st); seg_decode u3(a_s_one, dec_a_so);
    seg_decode u4(b_min, dec_b_m);   seg_decode u5(b_s_ten, dec_b_st); seg_decode u6(b_s_one, dec_b_so);

    // -----------------------------------------------------
    // 4. 화면 출력 (MUX)
    // -----------------------------------------------------
    reg [2:0] s_cnt;
    reg [7:0] seg_data_reg, seg_com_reg;
    assign seg_data = seg_data_reg;
    assign seg_com = seg_com_reg;

    always @(posedge clk) begin
        if (rst) s_cnt <= 0;
        else if (s_cnt >= 5) s_cnt <= 0;
        else s_cnt <= s_cnt + 1;
    end

    always @(posedge clk) begin
        if (rst) begin seg_com_reg <= 8'hFF; seg_data_reg <= 0; end
        else begin
            case(s_cnt)
                // 오른쪽 3자리 (Player B)
                3'd0: begin seg_com_reg <= 8'b1111_1110; seg_data_reg <= dec_b_so; end // 초(1)
                3'd1: begin seg_com_reg <= 8'b1111_1101; seg_data_reg <= dec_b_st; end // 초(10)
                3'd2: begin seg_com_reg <= 8'b1111_1011; seg_data_reg <= (b_min==0)? dec_b_m : (dec_b_m | 8'b1000_0000); end // 분 + 점(Dot)

                // 왼쪽 3자리 (Player A)
                3'd3: begin seg_com_reg <= 8'b1111_0111; seg_data_reg <= dec_a_so; end // 초(1)
                3'd4: begin seg_com_reg <= 8'b1110_1111; seg_data_reg <= dec_a_st; end // 초(10)
                3'd5: begin seg_com_reg <= 8'b1101_1111; seg_data_reg <= (a_min==0)? dec_a_m : (dec_a_m | 8'b1000_0000); end // 분 + 점(Dot)
                default: seg_com_reg <= 8'hFF;
            endcase
        end
    end

endmodule