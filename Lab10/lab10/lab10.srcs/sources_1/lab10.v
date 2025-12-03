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

localparam DIR_RIGHT = 2'd0;
localparam DIR_DOWN  = 2'd1;
localparam DIR_LEFT  = 2'd2;
localparam DIR_UP    = 2'd3;

localparam STATE_INIT    = 2'd0;
localparam STATE_PLAYING = 2'd1;
localparam STATE_GAMEOVER = 2'd2;

//========================================================================
// Signal Declarations
//========================================================================
wire [3:0] btn_pressed;

wire vga_clk, video_on, pixel_tick;
wire [9:0] pixel_x, pixel_y;
reg  [11:0] rgb_reg, rgb_next;

wire [11:0] bg_data, skin_data, data_in;
wire [17:0] bg_addr, skin_addr;
wire sram_we, sram_en;

reg [1:0] game_state;
reg [1:0] snake_direction, next_direction;
reg direction_changed;

reg [5:0] snake_x [0:SNAKE_MAX_LEN-1];
reg [5:0] snake_y [0:SNAKE_MAX_LEN-1];
reg [6:0] snake_length;

reg [1:0] curr_skin_index;
wire [17:0] skin_addr_base;

reg [26:0] move_counter;
localparam MOVE_SPEED = 27'd50_000_000;  // 5Hz
wire move_tick;

wire collision, self_collision, wall_collision;
reg self_collision_reg;
wire [5:0] current_grid_x;
wire [5:0] current_grid_y;
wire is_snake;
reg is_snake_reg;

wire transmit, received;
wire [7:0] rx_byte;
reg uart_data_read;
wire is_receiving, is_transmitting, recv_error;

// LCD signals
reg [127:0] row_A;
reg [127:0] row_B;

integer i;

assign usr_led = {snake_y[0][3:0]};
assign uart_tx = 1'b1;

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
sram #(
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
);

sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(SNAKE_SKIN_SIZE*SNAKE_SKIN_SIZE*3),
    .MEM_FILE("skin.mem")
) ram_skin (
    .clk(clk), 
    .we(sram_we), 
    .en(sram_en),
    .addr(skin_addr), 
    .data_i(data_in), 
    .data_o(skin_data)
);

assign sram_we = 1'b0;
assign sram_en = 1'b1;
assign data_in = 12'h000;

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
        if (usr_sw[0])
            curr_skin_index <= 2'd0;
        else if (usr_sw[1])
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
            STATE_INIT:    game_state <= STATE_PLAYING;
            STATE_PLAYING: if (collision) game_state <= STATE_GAMEOVER;
            STATE_GAMEOVER: if (|btn_pressed || received) game_state <= STATE_INIT;
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
            
            // Move head
            case (next_direction)
                DIR_RIGHT: snake_x[0] <= snake_x[0] + 5'd1;
                DIR_LEFT:  snake_x[0] <= snake_x[0] - 5'd1;
                DIR_DOWN:  snake_y[0] <= snake_y[0] + 5'd1;
                DIR_UP:    snake_y[0] <= snake_y[0] - 5'd1;
            endcase
        end
        
        if (move_tick) begin
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
wire [5:0] next_head_x = (next_direction == DIR_RIGHT) ? (snake_x[0] + 5'd1) :
                         (next_direction == DIR_LEFT)  ? (snake_x[0] - 5'd1) :
                         snake_x[0];

wire [5:0] next_head_y = (next_direction == DIR_DOWN) ? (snake_y[0] + 5'd1) :
                         (next_direction == DIR_UP)   ? (snake_y[0] - 5'd1) :
                         snake_y[0];

always @(*) begin
    self_collision_reg = 1'b0;
    for (i = 1; i < SNAKE_MAX_LEN; i = i + 1) begin
        if (i < snake_length) begin
            if (next_head_x == snake_x[i] && next_head_y == snake_y[i]) begin
                self_collision_reg = 1'b1;
            end
        end
    end
end

assign self_collision = self_collision_reg;


assign wall_collision = (next_head_x >= GRID_W-1) || (next_head_y >= GRID_H-1) ||
                        (next_head_x == 6'd0) || (next_head_y == 6'd0);

assign collision = wall_collision || self_collision;


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

// Texture coordinates

wire [8:0] pix_x_half = pixel_x >> 1;
wire [7:0] pix_y_half = pixel_y >> 1;

assign current_grid_x = pix_x_half / GRID_SIZE;  
assign current_grid_y = pix_y_half / GRID_SIZE;  

wire [4:0] snake_tex_x = pix_x_half % GRID_SIZE; 
wire [4:0] snake_tex_y = pix_y_half % GRID_SIZE; 

wire [8:0] grid_x_pixels = (current_grid_x << 4) + (current_grid_x << 2);
wire [8:0] grid_y_pixels = (current_grid_y << 4) + (current_grid_y << 2);

assign bg_addr = (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
assign skin_addr = skin_addr_base + snake_tex_y * SNAKE_SKIN_SIZE + snake_tex_x;

assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

always @(posedge clk) begin
    if (pixel_tick) rgb_reg <= rgb_next;
end

always @(*) begin
    if (~video_on) begin
        rgb_next = 12'h000;
    end else begin
        if (current_grid_x == 0 || current_grid_x == GRID_W-1 || 
            current_grid_y == 0 || current_grid_y == GRID_H-1) begin
            rgb_next = 12'h684;
        end
        else if (is_snake) begin
            rgb_next = skin_data;
        end 
        else begin
            rgb_next = bg_data;
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