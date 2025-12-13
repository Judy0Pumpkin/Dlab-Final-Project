`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// teamate1 版本
//////////////////////////////////////////////////////////////////////////////////

module lab10(
    input  clk,
    input  reset_n,
    input  [3:0] usr_btn,
    input  [3:0] usr_sw,
    output [3:0] usr_led,
    
    input  uart_rx,
    output uart_tx,
    
    // VGA ports
    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE,
    
    // LCD ports
    output LCD_RS,
    output LCD_RW,
    output LCD_E,
    output [3:0] LCD_D
);

//========================================================================
// Parameters
//========================================================================
localparam VBUF_W = 320;
localparam VBUF_H = 240;
localparam GRID_SIZE = 20;
localparam GRID_W = 16;
localparam GRID_H = 12;

localparam SNAKE_INIT_LEN = 5;
localparam SNAKE_MAX_LEN = 100;  
localparam SNAKE_INIT_X = 8;
localparam SNAKE_INIT_Y = 6;
localparam SNAKE_SKIN_SIZE = 20;
localparam TOTAL_SNAKE_SKIN_SIZE = 1200;

localparam DIR_RIGHT = 2'd0;
localparam DIR_DOWN  = 2'd1;
localparam DIR_LEFT  = 2'd2;
localparam DIR_UP    = 2'd3;

localparam STATE_INIT    = 2'd0;
localparam STATE_PLAYING = 2'd1;
localparam STATE_GAMEOVER = 2'd2;

localparam FRUIT_SIZE = 20;
localparam TOTAL_FRUIT_SIZE = 400;

localparam TOTAL_SCORE_TEXT_SIZE = 1200;
localparam TOTAL_SCORE_NUM_SIZE = 3600;

localparam OBSTACLE_NUM = 5;
localparam OBSTACLE_SIZE = 20;
localparam TOTAL_OBSTACLE_SIZE = 400;

localparam START_W = 267;
localparam START_H = 49;
localparam START_SIZE = 13083;

localparam MAP_ICON_W = 72;
localparam MAP_ICON_H = 38;
localparam MAP_ICON_SIZE = 2736;

localparam OVER_W = 246;
localparam OVER_H = 28;
localparam OVER_SIZE = 6888;

localparam CHOOSE_W = 183;      
localparam CHOOSE_H = 21;      
localparam CHOOSE_SIZE = 3843;

localparam PREVIEW_X = 280;
localparam PREVIEW_Y = 150;
//========================================================================
// Signal Declarations
//========================================================================
wire [3:0] btn_pressed;

wire vga_clk, video_on, pixel_tick;
wire [9:0] pixel_x, pixel_y;
reg  [11:0] rgb_reg, rgb_next;

wire [11:0] bg_data, skin_data, fruit_data, score_text_data, score_num_data, obstacle_data, data_in;
wire [17:0] bg_addr, skin_addr, fruit_addr, score_text_addr, score_num_addr, obstacle_addr;
wire sram_we, sram_en;

reg [1:0] game_state;
reg [1:0] snake_direction, next_direction;
reg direction_changed;

reg [5:0] snake_x [0:SNAKE_MAX_LEN-1];
reg [5:0] snake_y [0:SNAKE_MAX_LEN-1];
reg [6:0] snake_length;

wire [5:0] next_head_x, next_head_y;

reg [1:0] curr_skin_index;
wire [17:0] skin_addr_base;

reg [5:0] fruit_x, fruit_y;
wire [5:0] rand_x, rand_y;
reg fruit_vaild, fruit_on_field, fruit_eat;

reg [3:0] obstacle_pos_x[0:4], obstacle_pos_y[0:4];

reg [7:0] score_10, score_1, score;
wire [17:0] score_addr_base;
wire [9:0] score_text_addr_base;

reg [26:0] move_counter;
localparam MOVE_SPEED = 27'd50_000_000;  // 5Hz
wire move_tick;

wire collision, self_collision, wall_collision, obstacle_collision;
reg self_collision_reg;
wire [5:0] current_grid_x;
wire [5:0] current_grid_y;
wire is_snake, is_fruit, is_score_text, is_score_num_1, is_score_num_10, is_obstacle;
reg is_snake_reg;

wire transmit, received;
wire [7:0] rx_byte;
reg uart_data_read;
wire is_receiving, is_transmitting, recv_error;

// LCD signals
reg [127:0] row_A;
reg [127:0] row_B;

integer i;

assign usr_led = fruit_x;
assign uart_tx = 1'b1;

wire [11:0] start_data, map1_img_data, map2_img_data, over_data, choose_data;
wire [17:0] start_addr, map1_img_addr, map2_img_addr, over_addr, choose_addr;

//========================================================================
// Debounce
//========================================================================
debounce #(.DEBOUNCE_PERIOD(2_000_000)) btn_db0 (
    .clk(clk), .btn_input(usr_btn[0]), .btn_output(btn_pressed[0])
);
debounce #(.DEBOUNCE_PERIOD(2_000_000)) btn_db1 (
    .clk(clk), .btn_input(usr_btn[1]), .btn_output(btn_pressed[1])
);
debounce #(.DEBOUNCE_PERIOD(2_000_000)) btn_db2 (
    .clk(clk), .btn_input(usr_btn[2]), .btn_output(btn_pressed[2])
);
debounce #(.DEBOUNCE_PERIOD(2_000_000)) btn_db3 (
    .clk(clk), .btn_input(usr_btn[3]), .btn_output(btn_pressed[3])
);

//========================================================================
// SRAM
//========================================================================
/*sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(VBUF_W*VBUF_H),
    .MEM_FILE("background.mem")
) ram_bg (
    .clk(clk), 
    .we(sram_we), 
    .en(sram_en),
    .addr(bg_addr), 
    .data_i(data_in), 
    .data_o(bg_data)
);*/
//目前背景都用純色所以不用讀bg_data 可以省LUT 之後如果改背景再做

sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(TOTAL_SNAKE_SKIN_SIZE),
    .MEM_FILE("skin.mem")
) ram_skin (
    .clk(clk), 
    .we(sram_we), 
    .en(sram_en),
    .addr(skin_addr), 
    .data_i(data_in), 
    .data_o(skin_data)
);

sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(TOTAL_FRUIT_SIZE),
    .MEM_FILE("fruit.mem")
) ram_fruit (
    .clk(clk), 
    .we(sram_we), 
    .en(sram_en),
    .addr(fruit_addr), 
    .data_i(data_in), 
    .data_o(fruit_data)
);

sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(TOTAL_SCORE_TEXT_SIZE),
    .MEM_FILE("score_text.mem")
) ram_score_text (
    .clk(clk), 
    .we(sram_we), 
    .en(sram_en),
    .addr(score_text_addr), 
    .data_i(data_in), 
    .data_o(score_text_data)
);

sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(TOTAL_SCORE_NUM_SIZE),
    .MEM_FILE("score_num.mem")
) ram_score_num (
    .clk(clk), 
    .we(sram_we), 
    .en(sram_en),
    .addr(score_num_addr), 
    .data_i(data_in), 
    .data_o(score_num_data)
);

sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(TOTAL_OBSTACLE_SIZE),
    .MEM_FILE("obstacle.mem")
) ram_obstacle (
    .clk(clk), 
    .we(sram_we), 
    .en(sram_en),
    .addr(obstacle_addr), 
    .data_i(data_in), 
    .data_o(obstacle_data)
);
assign sram_we = 1'b0;
assign sram_en = 1'b1;
assign data_in = 12'h000;

sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(START_SIZE), 
    .MEM_FILE("gamestart.mem")
) ram_start (
    .clk(clk), 
    .we(1'b0), 
    .en(1'b1), 
    .addr(start_addr), 
    .data_i(12'h0), 
    .data_o(start_data)
);

sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(MAP_ICON_SIZE), 
    .MEM_FILE("map1.mem")
) ram_map1_img (
    .clk(clk), 
    .we(1'b0), 
    .en(1'b1), 
    .addr(map1_img_addr), 
    .data_i(12'h0), 
    .data_o(map1_img_data)
);

sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(MAP_ICON_SIZE), 
    .MEM_FILE("map2.mem")
) ram_map2_img (
    .clk(clk), 
    .we(1'b0), 
    .en(1'b1), 
    .addr(map2_img_addr), 
    .data_i(12'h0), 
    .data_o(map2_img_data)
);

sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(OVER_SIZE),     
    .MEM_FILE("gameover.mem")  
) ram_over (
    .clk(clk), 
    .we(1'b0), 
    .en(1'b1), 
    .addr(over_addr), 
    .data_i(12'h0), 
    .data_o(over_data)
);

sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(CHOOSE_SIZE),      
    .MEM_FILE("choose.mem")   
) ram_choose (
    .clk(clk), 
    .we(1'b0), 
    .en(1'b1), 
    .addr(choose_addr), 
    .data_i(12'h0), 
    .data_o(choose_data)
);

//========================================================================
// VGA Controller
//========================================================================
vga_sync vs0(
    .clk(vga_clk), 
    .reset(~reset_n), 
    .oHS(VGA_HSYNC), 
    .oVS(VGA_VSYNC),
    .visible(video_on), 
    .p_tick(pixel_tick),
    .pixel_x(pixel_x), 
    .pixel_y(pixel_y)
);

clk_divider #(2) clk_divider0(
    .clk(clk),
    .reset(~reset_n),
    .clk_out(vga_clk)
);

//========================================================================
// UART
//========================================================================
uart uart_inst(
    .clk(clk),
    .rst(~reset_n),
    .rx(uart_rx),
    .tx(),
    .transmit(transmit),
    .tx_byte(8'h00),
    .received(received),
    .rx_byte(rx_byte),
    .is_receiving(is_receiving),
    .is_transmitting(is_transmitting),
    .recv_error(recv_error)
);

assign transmit = 1'b0;

//========================================================================
// Skin Selection
//========================================================================
always @(posedge clk) begin
    if (~reset_n) begin
        curr_skin_index <= 2'd0;
    end else begin
        /*if (usr_sw[0])
            curr_skin_index <= 2'd0;
        else if (usr_sw[1])
            curr_skin_index <= 2'd1;
        else if (usr_sw[2])
            curr_skin_index <= 2'd2;
        else
            curr_skin_index <= 2'd0;*/
        if (usr_sw[1])          
            curr_skin_index <= 2'd1; 
        else if (usr_sw[2])     
            curr_skin_index <= 2'd2;
        else
            curr_skin_index <= 2'd0;
    end
end

// Use combinational logic instead of array
assign skin_addr_base = (curr_skin_index == 2'd1) ? 18'd400 :
                        (curr_skin_index == 2'd2) ? 18'd800 :
                        18'd0;

//========================================================================
// Game State Machine
//========================================================================
always @(posedge clk) begin
    if (~reset_n) begin
        game_state <= STATE_INIT;
    end else begin
        case (game_state)
            STATE_INIT: if (btn_pressed[0]) game_state <= STATE_PLAYING;
            STATE_PLAYING: if (self_collision || score == 0) game_state <= STATE_GAMEOVER;
            STATE_GAMEOVER: if (btn_pressed[0] || received) game_state <= STATE_INIT;
            default:       game_state <= STATE_INIT;
        endcase
    end
end

//========================================================================
// Snake Initialization
//========================================================================
always @(posedge clk) begin
    if (~reset_n || game_state == STATE_INIT) begin
        // Initialize snake
        snake_length <= SNAKE_INIT_LEN;
        snake_direction <= DIR_RIGHT;
        next_direction <= DIR_RIGHT;
        direction_changed <= 1'b0;
        uart_data_read <= 1'b0;
        for (i = 0; i < SNAKE_MAX_LEN; i = i + 1) begin
            if (i < SNAKE_INIT_LEN) begin
                snake_x[i] <= SNAKE_INIT_X - i;
                snake_y[i] <= SNAKE_INIT_Y;
            end else begin
                snake_x[i] <= 5'd0;
                snake_y[i] <= 5'd0;
            end
        end
    end else if (game_state == STATE_PLAYING) begin
        
        // Input Control
        if (!direction_changed) begin
            if (btn_pressed[0] && snake_direction != DIR_DOWN) begin
                next_direction <= DIR_UP;
                direction_changed <= 1'b1;
            end
            else if (btn_pressed[1] && snake_direction != DIR_UP) begin
                next_direction <= DIR_DOWN;
                direction_changed <= 1'b1;
            end
            else if (btn_pressed[2] && snake_direction != DIR_RIGHT) begin
                next_direction <= DIR_LEFT;
                direction_changed <= 1'b1;
            end
            else if (btn_pressed[3] && snake_direction != DIR_LEFT) begin
                next_direction <= DIR_RIGHT;
                direction_changed <= 1'b1;
            end
            else if (received && !uart_data_read) begin
                uart_data_read <= 1'b1;
                case (rx_byte)
                    8'h77, 8'h57: 
                        if (snake_direction != DIR_DOWN) begin
                            next_direction <= DIR_UP;
                            direction_changed <= 1'b1;
                        end
                    8'h73, 8'h53:
                        if (snake_direction != DIR_UP) begin
                            next_direction <= DIR_DOWN;
                            direction_changed <= 1'b1;
                        end
                    8'h61, 8'h41:
                        if (snake_direction != DIR_RIGHT) begin
                            next_direction <= DIR_LEFT;
                            direction_changed <= 1'b1;
                        end
                    8'h64, 8'h44:
                        if (snake_direction != DIR_LEFT) begin
                            next_direction <= DIR_RIGHT;
                            direction_changed <= 1'b1;
                        end
                endcase
            end
        end
        
        if (!received) uart_data_read <= 1'b0;
        
        // Movement
        if (move_tick && !collision) begin
            direction_changed <= 1'b0;
            snake_direction <= next_direction;
            
            // Move body
            for (i = SNAKE_MAX_LEN-1; i > 0; i = i - 1) begin
                if (i < snake_length) begin
                    snake_x[i] <= snake_x[i-1];
                    snake_y[i] <= snake_y[i-1];
                end
            end
            // Add length
                if(next_head_x == fruit_x && next_head_y == fruit_y) begin
                    snake_x[snake_length] = snake_x[snake_length - 1];
                    snake_y[snake_length] = snake_y[snake_length - 1];
                    snake_length <= snake_length + 1;
                end
            
            // Move head
            case (next_direction)
                DIR_RIGHT: snake_x[0] <= snake_x[0] + 5'd1;
                DIR_LEFT:  snake_x[0] <= snake_x[0] - 5'd1;
                DIR_DOWN:  snake_y[0] <= snake_y[0] + 5'd1;
                DIR_UP:    snake_y[0] <= snake_y[0] - 5'd1;
            endcase
        end
        else if (move_tick) begin
            direction_changed <= 1'b0;
        end
        
        
    end else begin
        direction_changed <= 1'b0;
        uart_data_read <= 1'b0;
    end
end

//========================================================================
// Movement Timer
//========================================================================
always @(posedge clk) begin
    if (~reset_n || game_state != STATE_PLAYING) begin
        move_counter <= 0;
    end else begin
        if (move_counter >= MOVE_SPEED - 1)
            move_counter <= 0;
        else
            move_counter <= move_counter + 1;
    end
end

assign move_tick = (move_counter == MOVE_SPEED - 1);

//========================================================================
// Collision Detection
//========================================================================
assign next_head_x = (next_direction == DIR_RIGHT) ? (snake_x[0] + 5'd1) :
                         (next_direction == DIR_LEFT)  ? (snake_x[0] - 5'd1) :
                         snake_x[0];

assign next_head_y = (next_direction == DIR_DOWN) ? (snake_y[0] + 5'd1) :
                         (next_direction == DIR_UP)   ? (snake_y[0] - 5'd1) :
                         snake_y[0];

always @(*) begin
    self_collision_reg = 1'b0;
    for (i = 1; i < SNAKE_MAX_LEN; i = i + 1) begin
        if (i < snake_length) begin
            if (snake_x[0] == snake_x[i] && snake_y[0] == snake_y[i]) begin
                self_collision_reg = 1'b1;
            end
        end
    end
end

assign self_collision = self_collision_reg;


assign wall_collision = (next_head_x >= GRID_W-1) || (next_head_y >= GRID_H-1) ||
                        (next_head_x == 6'd0) || (next_head_y == 6'd0);
                        
assign obstacle_collision = (next_head_x == obstacle_pos_x[0] && next_head_y == obstacle_pos_y[0]) ||
                            (next_head_x == obstacle_pos_x[1] && next_head_y == obstacle_pos_y[1]) ||
                            (next_head_x == obstacle_pos_x[2] && next_head_y == obstacle_pos_y[2]) ||
                            (next_head_x == obstacle_pos_x[3] && next_head_y == obstacle_pos_y[3]) ||
                            (next_head_x == obstacle_pos_x[4] && next_head_y == obstacle_pos_y[4]);

assign collision = wall_collision || obstacle_collision;

//========================================================================
// Fruit Generating
//========================================================================
random_num#(
    .mod(14)
)random_fruit_x(
    .clk(clk),
    .rst(~reset_n),
    .rand_num(rand_x)
);

random_num#(
    .mod(10)
)random_fruit_y(
    .clk(clk),
    .rst(~reset_n),
    .rand_num(rand_y)
);
//判斷生成出來的食物會不會撞到蛇/障礙物
always @(*) begin
    fruit_vaild = 1'b1;
    for (i = 0; i < SNAKE_MAX_LEN; i = i + 1) begin
        if (i < snake_length) begin
            if (rand_x + 1 == snake_x[i] && rand_y + 1 == snake_y[i]) begin
                fruit_vaild = 1'b0;
            end
        end
    end
    for (i = 0; i < OBSTACLE_NUM; i = i + 1) begin
        if (rand_x + 1 == obstacle_pos_x[i] && rand_y + 1 == obstacle_pos_y[i]) begin
            fruit_vaild = 1'b0;
        end
    end
end

always @(posedge clk) begin
    if(~reset_n || game_state == STATE_INIT) begin
        fruit_x <= 0;
        fruit_y <= 0;
        fruit_eat <= 0;
        fruit_on_field <= 0;
    end
    else if(game_state == STATE_PLAYING) begin
    
        if(fruit_eat) begin
            fruit_x <= 0;
            fruit_y <= 0;
            fruit_on_field <= 0;
            fruit_eat <= 0;
        end
        else begin
            if (fruit_x == snake_x[0] && fruit_y == snake_y[0]) begin
                fruit_eat = 1'b1;
            end
        end
        
        if(!fruit_on_field) begin
            if(fruit_vaild) begin
                fruit_x <= rand_x + 1;
                fruit_y <= rand_y + 1;
                fruit_on_field <= 1;
            end
        end
    end
end

//========================================================================
// Obstacles
//========================================================================


always @(posedge clk) begin
    if(~reset_n || game_state == STATE_INIT) begin
        /*obstacle_pos_x[0] <= 4;
        obstacle_pos_y[0] <= 3;
        obstacle_pos_x[1] <= 11;
        obstacle_pos_y[1] <= 2;
        obstacle_pos_x[2] <= 5;
        obstacle_pos_y[2] <= 8;
        obstacle_pos_x[3] <= 7;
        obstacle_pos_y[3] <= 4;
        obstacle_pos_x[4] <= 12;
        obstacle_pos_y[4] <= 8;*/
        if (usr_sw[0] == 1'b1) begin
            obstacle_pos_x[0] <= 4;  obstacle_pos_y[0] <= 3;
            obstacle_pos_x[1] <= 11; obstacle_pos_y[1] <= 2;
            obstacle_pos_x[2] <= 5;  obstacle_pos_y[2] <= 8;
            obstacle_pos_x[3] <= 7;  obstacle_pos_y[3] <= 4;
            obstacle_pos_x[4] <= 12; obstacle_pos_y[4] <= 8;
        end
        else begin
            obstacle_pos_x[0] <= 3;  obstacle_pos_y[0] <= 3;
            obstacle_pos_x[1] <= 3;  obstacle_pos_y[1] <= 4;
            obstacle_pos_x[2] <= 3;  obstacle_pos_y[2] <= 5;
            obstacle_pos_x[3] <= 12; obstacle_pos_y[3] <= 6;
            obstacle_pos_x[4] <= 12; obstacle_pos_y[4] <= 7;
        end
    end
end

//========================================================================
// Score
//========================================================================

always @(posedge clk) begin
    if(~reset_n || game_state == STATE_INIT) begin
        score <= 5;
        score_1 <= 5;
        score_10 <= 0;
    end
    else if(game_state == STATE_PLAYING) begin
        if(fruit_eat) begin
            if(score_1 == 9) begin
                score_1 <= 0;
                score_10 <= score_10 + 1;
            end
            else score_1 <= score_1 + 1;
        end
        
        //撞到牆/障礙的話每一次move_tick就扣一分
        else if(move_tick && collision) begin
            if(score_1 == 0) begin
                score_1 <= 9;
                score_10 <= score_10 - 1;
            end
            else score_1 <= score_1 - 1;
        end
        score <= score_10 * 10 + score_1;
    end
end

assign score_addr_base = (is_score_num_10)? (score_10 == 1) ? 18'd0400 :
                                            (score_10 == 2) ? 18'd0800 :
                                            (score_10 == 3) ? 18'd1200 :
                                            (score_10 == 4) ? 18'd1600 :
                                            (score_10 == 5) ? 18'd2000 :
                                            (score_10 == 6) ? 18'd2400 :
                                            (score_10 == 7) ? 18'd2800 :
                                            (score_10 == 8) ? 18'd3200 :
                                            (score_10 == 9) ? 18'd3600 :
                                                              18'd0000 :
                                            (score_1 == 1)  ? 18'd0400 :
                                            (score_1 == 2)  ? 18'd0800 :
                                            (score_1 == 3)  ? 18'd1200 :
                                            (score_1 == 4)  ? 18'd1600 :
                                            (score_1 == 5)  ? 18'd2000 :
                                            (score_1 == 6)  ? 18'd2400 :
                                            (score_1 == 7)  ? 18'd2800 :
                                            (score_1 == 8)  ? 18'd3200 :
                                            (score_1 == 9)  ? 18'd3600 :
                                                              18'd0000 ;

assign score_text_addr_base = (((pixel_x >> 1) / GRID_SIZE) == 12)? 18'd400:
                              (((pixel_x >> 1) / GRID_SIZE) == 13)? 18'd800:
                                                                    18'd000;
//========================================================================
// VGA Rendering
//========================================================================


// Check if pixel is snake
always @(*) begin
    is_snake_reg = 1'b0;
    for (i = 0; i < SNAKE_MAX_LEN; i = i + 1) begin
        if (i < snake_length) begin
            if (current_grid_x == snake_x[i] && current_grid_y == snake_y[i]) begin
                is_snake_reg = 1'b1;
            end
        end
    end
end

assign is_snake = is_snake_reg;
assign is_fruit = (fruit_x == current_grid_x && fruit_y == current_grid_y) && fruit_on_field;
assign is_score_text = (current_grid_x >= 11 && current_grid_x <= 13 && current_grid_y == 0);
assign is_score_num_10 = (current_grid_x == 14 && current_grid_y == 0);
assign is_score_num_1 = (current_grid_x == 15 && current_grid_y == 0);
assign is_obstacle = (current_grid_x == obstacle_pos_x[0] && current_grid_y == obstacle_pos_y[0]) ||
                     (current_grid_x == obstacle_pos_x[1] && current_grid_y == obstacle_pos_y[1]) ||
                     (current_grid_x == obstacle_pos_x[2] && current_grid_y == obstacle_pos_y[2]) ||
                     (current_grid_x == obstacle_pos_x[3] && current_grid_y == obstacle_pos_y[3]) ||
                     (current_grid_x == obstacle_pos_x[4] && current_grid_y == obstacle_pos_y[4]);
// Texture coordinates

wire [8:0] pix_x_half = pixel_x >> 1;
wire [7:0] pix_y_half = pixel_y >> 1;

assign current_grid_x = (pixel_x >> 1) / GRID_SIZE;  
assign current_grid_y = (pixel_y >> 1) / GRID_SIZE;  

wire [4:0] snake_tex_x = pix_x_half % GRID_SIZE; 
wire [4:0] snake_tex_y = pix_y_half % GRID_SIZE; 

wire [4:0] grid_pixel_x = pix_x_half % GRID_SIZE; 
wire [4:0] grid_pixel_y = pix_y_half % GRID_SIZE; 

//wire [8:0] grid_x_pixels = (current_grid_x << 4) + (current_grid_x << 2);
//wire [8:0] grid_y_pixels = (current_grid_y << 4) + (current_grid_y << 2);

//skin
wire is_skin_preview = (pix_x_half >= PREVIEW_X && pix_x_half < PREVIEW_X + SNAKE_SKIN_SIZE && 
                        pix_y_half >= PREVIEW_Y && pix_y_half < PREVIEW_Y + SNAKE_SKIN_SIZE);

wire is_skin_border_box = (pix_x_half >= PREVIEW_X - 2 && pix_x_half < PREVIEW_X + SNAKE_SKIN_SIZE + 2 && 
                           pix_y_half >= PREVIEW_Y - 2 && pix_y_half < PREVIEW_Y + SNAKE_SKIN_SIZE + 2);

assign bg_addr = (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
//assign skin_addr = skin_addr_base + snake_tex_y * SNAKE_SKIN_SIZE + snake_tex_x;
assign skin_addr = (game_state == STATE_INIT && is_skin_preview)?
                   (skin_addr_base + (pix_y_half - PREVIEW_Y) * SNAKE_SKIN_SIZE + (pix_x_half - PREVIEW_X)) :
                   (skin_addr_base + snake_tex_y * SNAKE_SKIN_SIZE + snake_tex_x);
assign fruit_addr = grid_pixel_y * FRUIT_SIZE + grid_pixel_x;
assign score_text_addr = pix_y_half * GRID_SIZE *3 + grid_pixel_x + ((pix_x_half / GRID_SIZE) - 11) * GRID_SIZE;
assign score_num_addr = (is_score_num_10) ? grid_pixel_y * GRID_SIZE + grid_pixel_x + score_addr_base
                                          : grid_pixel_y * GRID_SIZE + grid_pixel_x + score_addr_base;
assign obstacle_addr = grid_pixel_y * GRID_SIZE + grid_pixel_x;

assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

wire is_start_area = (pix_x_half >= 26 && pix_x_half < 293 && pix_y_half >= 40 && pix_y_half < 89);
assign start_addr = (pix_y_half - 40) * START_W + (pix_x_half - 26);
//Map 1 
wire is_map1_area = (pix_x_half >= 64 && pix_x_half < 136 && pix_y_half >= 140 && pix_y_half < 178);
assign map1_img_addr = (pix_y_half - 140) * MAP_ICON_W + (pix_x_half - 64);

// Map 2 
wire is_map2_area = (pix_x_half >= 184 && pix_x_half < 256 && pix_y_half >= 140 && pix_y_half < 178);
assign map2_img_addr = (pix_y_half - 140) * MAP_ICON_W + (pix_x_half - 184);

// 白色選取邊框
wire is_border_1 = (pix_x_half >= 62 && pix_x_half < 138 && pix_y_half >= 138 && pix_y_half < 180);
wire is_border_2 = (pix_x_half >= 182 && pix_x_half < 258 && pix_y_half >= 138 && pix_y_half < 180);

//Game Over 
wire is_over_area = (pix_x_half >= 37 && pix_x_half < 283 && pix_y_half >= 100 && pix_y_half < 128);
assign over_addr = (pix_y_half - 100) * OVER_W + (pix_x_half - 37);

wire is_choose_area = (pix_x_half >= 5 && pix_x_half < 188 && 
                       pix_y_half >= 210 && pix_y_half < 231);
assign choose_addr = (pix_y_half - 210) * CHOOSE_W + (pix_x_half - 5);


always @(posedge clk) begin
    if (pixel_tick) rgb_reg <= rgb_next;
end

always @(posedge clk) begin
    if (~video_on) begin
        rgb_next <= 12'h000;
    end 
    else begin
        // ============================================================
        // 狀態 1: 初始選單畫面 
        // ============================================================
        if (game_state == STATE_INIT) begin
            if (is_start_area && start_data != 12'h0f0) begin
                rgb_next <= start_data;
            end
            else if (is_map1_area && map1_img_data != 12'h0f0) begin
                rgb_next <= map1_img_data;
            end
            else if (is_map2_area && map2_img_data != 12'h0f0) begin
                rgb_next <= map2_img_data;
            end
            else if (is_choose_area && choose_data != 12'h0f0) begin
            rgb_next <= choose_data;
            end
            else if (usr_sw[0] == 1'b0 && is_border_1 && !is_map1_area) begin
                rgb_next <= 12'hFFF; 
            end
            else if (usr_sw[0] == 1'b1 && is_border_2 && !is_map2_area) begin
                rgb_next <= 12'hFFF;
            end
            else if (is_skin_preview) begin
                rgb_next <= skin_data; 
            end
            else if (is_skin_border_box) begin
                rgb_next <= 12'hFFF;   
            end
            else begin
                rgb_next <= 12'h003; 
            end
        end
        
        // ============================================================
        // 狀態 2: 遊戲結束畫面
        // ============================================================
        else if (game_state == STATE_GAMEOVER) begin
            if (is_over_area && over_data != 12'h0f0) begin
                rgb_next <= over_data;
            end
            else begin
                rgb_next <= 12'h300; 
            end
        end
        else begin
            if (is_score_text && score_text_data != 12'h0f0) begin
                rgb_next <= score_text_data;
            end
            else if ((is_score_num_1 || is_score_num_10) && score_num_data != 12'h0f0) begin
                rgb_next <= score_num_data;
            end
            else if (current_grid_x == 0 || current_grid_x == GRID_W-1 || 
                current_grid_y == 0 || current_grid_y == GRID_H-1) begin
                rgb_next <= 12'h684;
            end
            else if (is_snake) begin
                rgb_next <= skin_data;
            end 
            else if (is_fruit && fruit_data != 12'h0f0) begin
                rgb_next <= fruit_data;
            end
            else if (is_obstacle) begin
                if(obstacle_data == 12'h0f0) rgb_next <= 12'h000;
                else rgb_next <= obstacle_data;
            end
            else begin
                if((current_grid_x + current_grid_y) % 2) rgb_next = 12'h8a5;
                else rgb_next <= 12'h9c6;
            end
        end
    end
end

//========================================================================
// LCD Module
//========================================================================
LCD_module lcd0(
    .clk(clk),
    .reset(~reset_n),
    .row_A(row_A),
    .row_B(row_B),
    .LCD_E(LCD_E),
    .LCD_RS(LCD_RS),
    .LCD_RW(LCD_RW),
    .LCD_D(LCD_D)
);

//========================================================================
// LCD Display Logic
//========================================================================
reg [7:0] head_x_tens, head_x_ones;
reg [7:0] head_y_tens, head_y_ones;
reg [7:0] len_tens, len_ones;

//always @(posedge clk) begin
//    if (~reset_n) begin
//        row_A <= "reseting        ";
//        row_B <= "loading         ";
//    end
//    else begin
//        head_x_tens = 8'd48 + (snake_x[0] / 10);
//        head_x_ones = 8'd48 + (snake_x[0] % 10);
//        head_y_tens = 8'd48 + (snake_y[0] / 10);
//        head_y_ones = 8'd48 + (snake_y[0] % 10);
//        len_tens = 8'd48 + (snake_length / 10);
//        len_ones = 8'd48 + (snake_length % 10);
        
//        row_A = {"Head:[", 
//                 head_x_tens, head_x_ones, ",",
//                 head_y_tens, head_y_ones,
//                 "]     "};
        
//        case (game_state)
//            STATE_INIT: 
//                row_B = {"ST:I ", collision ? "C:Y" : "C:N", " Len:", len_tens, len_ones, " "};
//            STATE_PLAYING:
//                row_B = {"ST:P ", collision ? "C:Y" : "C:N", " Len:", len_tens, len_ones, " "};
//            STATE_GAMEOVER:
//                row_B = {"ST:G ", collision ? "C:Y" : "C:N", " Len:", len_tens, len_ones, " "};
//            default:
//                row_B = {"ST:? C:? Len:?? "};
//        endcase
//    end
//end

always @(*) begin
    row_A = "Snake Game Test ";
    row_B = "LCD Working?    ";
end


endmodule