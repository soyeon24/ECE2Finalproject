module stopwatch (
    input clk,              // 1ms 단위 클럭 (반드시 분주된 클럭이어야 함)
    input rst,              // 시스템 리셋
    input start_btn,        // SW0: 시작
    input stop_btn,         // SW1: 정지
    input clear_btn,        // SW2: 리셋 (00:00 초기화)
    input lap_btn,          // SW4: 랩 타임 기록 (저장)
    
    // 7-Segment 표시용 (현재 시간)
    output [7:0] seg_data,
    output [7:0] seg_com,
    
    // [NEW] LCD 모듈로 보낼 저장된 랩 타임 데이터
    output [3:0] o_lap_m_ten, 
    output [3:0] o_lap_m_one,
    output [3:0] o_lap_s_ten, 
    output [3:0] o_lap_s_one
);

    // 내부 상태 레지스터
    reg is_running;
    reg [9:0] ms_cnt;
    reg [3:0] m_ten, m_one, s_ten, s_one;

    // 랩 타임 저장용 레지스터
    reg [3:0] lap_m_ten, lap_m_one, lap_s_ten, lap_s_one;

    // 7-Segment 디코딩 와이어
    wire [7:0] seg_m_ten, seg_m_one, seg_s_ten, seg_s_one;
    
    // FND 스캔용 변수
    reg [1:0] s_cnt;
    reg [7:0] seg_data_reg;
    reg [7:0] seg_com_reg;

    assign seg_data = seg_data_reg;
    assign seg_com  = seg_com_reg;

    // ====================================================
    // 1. 동작 제어 (Start / Stop)
    // ====================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            is_running <= 0;
        end 
        else if (clear_btn) begin 
            is_running <= 0; // SW2(Reset) 누르면 멈춤 상태로 전환
        end
        else begin
            if (start_btn) is_running <= 1;      // SW0: Start
            else if (stop_btn) is_running <= 0;  // SW1: Stop
        end
    end

    // ====================================================
    // 2. 랩 타임 기록 (SW4 Edge Detection)
    // ====================================================
    reg lap_btn_prev;
    wire lap_btn_rise = lap_btn & ~lap_btn_prev; // Rising Edge 감지

    always @(posedge clk) begin
        if (rst) lap_btn_prev <= 0;
        else lap_btn_prev <= lap_btn;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            lap_m_ten <= 0; lap_m_one <= 0; 
            lap_s_ten <= 0; lap_s_one <= 0;
        end 
        else if (clear_btn) begin 
            // SW2(Reset) 시 저장된 랩타임도 초기화 (선택 사항: 원치 않으면 이 부분 삭제)
            lap_m_ten <= 0; lap_m_one <= 0; 
            lap_s_ten <= 0; lap_s_one <= 0;
        end 
        else if (lap_btn_rise) begin 
            // SW4 눌리는 순간 현재 시간(레지스터)을 랩타임 레지스터에 복사
            lap_m_ten <= m_ten;
            lap_m_one <= m_one;
            lap_s_ten <= s_ten;
            lap_s_one <= s_one;
        end
    end

    // ====================================================
    // 3. 시간 카운터 로직 (분:초:밀리초)
    // ====================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ms_cnt <= 0;
            s_one <= 0; s_ten <= 0; m_one <= 0; m_ten <= 0;
        end 
        else if (clear_btn) begin // SW2: 카운터 0으로 초기화
            ms_cnt <= 0;
            s_one <= 0; s_ten <= 0; m_one <= 0; m_ten <= 0;
        end
        else if (is_running) begin
            if (ms_cnt >= 999) begin // 1000ms = 1초
                ms_cnt <= 0;
                if (s_one >= 9) begin
                    s_one <= 0;
                    if (s_ten >= 5) begin
                        s_ten <= 0;
                        if (m_one >= 9) begin
                            m_one <= 0;
                            if (m_ten >= 5) m_ten <= 0;
                            else m_ten <= m_ten + 1;
                        end else m_one <= m_one + 1;
                    end else s_ten <= s_ten + 1;
                end else s_one <= s_one + 1;
            end else ms_cnt <= ms_cnt + 1;
        end
    end

    // ====================================================
    // 4. 7-Segment 디스플레이 로직 (Multiplexing)
    // ====================================================
    // seg_decode 모듈이 같은 프로젝트 내에 있어야 합니다.
    seg_decode u_m_ten (m_ten, seg_m_ten);
    seg_decode u_m_one (m_one, seg_m_one);
    seg_decode u_s_ten (s_ten, seg_s_ten);
    seg_decode u_s_one (s_one, seg_s_one);

    always @(posedge clk) begin
        if (rst) s_cnt <= 0;
        else s_cnt <= s_cnt + 1;
    end

    always @(posedge clk) begin
        if (rst) seg_com_reg <= 8'b1111_1111;
        else case (s_cnt)
            2'd0: seg_com_reg <= 8'b1111_0111; // 분 10의 자리
            2'd1: seg_com_reg <= 8'b1111_1011; // 분 1의 자리
            2'd2: seg_com_reg <= 8'b1111_1101; // 초 10의 자리
            2'd3: seg_com_reg <= 8'b1111_1110; // 초 1의 자리
            default: seg_com_reg <= 8'b1111_1111;
        endcase
    end

    always @(posedge clk) begin
        if (rst) seg_data_reg <= 8'b0000_0000;
        else case (s_cnt)
            2'd0: seg_data_reg <= seg_m_ten;
            2'd1: seg_data_reg <= seg_m_one;
            2'd2: seg_data_reg <= seg_s_ten;
            2'd3: seg_data_reg <= seg_s_one;
            default: seg_data_reg <= 8'b0000_0000;
        endcase
    end

    // ====================================================
    // 5. 최종 출력 연결 (LCD 모듈용)
    // ====================================================
    // 여기서 나가는 신호가 Lab Record 모듈의 입력이 됩니다.
    assign o_lap_m_ten = lap_m_ten;
    assign o_lap_m_one = lap_m_one;
    assign o_lap_s_ten = lap_s_ten;
    assign o_lap_s_one = lap_s_one;

endmodule