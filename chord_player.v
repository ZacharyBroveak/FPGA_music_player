`define LOAD 6'b000001 // general LOAD state, waits for new_note from song_reader
`define LOAD_0 6'b000010 // three note slots to load new notes, they are loaded from 0 to 2 whichever spot is first open, if no slots are
                         // are open, the new note from song_reader is dropped
`define LOAD_1 6'b000100
`define LOAD_2 6'b001000
`define SET_DURATION 6'b010000 // set_duration state gives us a cycle to update the the duration left for our notes inside chord_fsm we can 
                               // keep track of note durations in the chord FSM independent of the note_players because the note_players only load 
                               // the duration during the LOAD_X state, they won't skip duration due to set_duration because load_new_note_x is low
`define PLAY_CHORD 6'b100000 // chord_fsm sends play signal to note_players for as long as counter

module chord_player(
    input clk,
    input rst,
    input play, // tells us when it is ok to decrement the counter during the advance state (chord is playing)
    input beat, // allows us to play chords aligned to 1/48th second pulses
    input new_note, // tells us when song_reader has provided a new note that we must update the state for
    input [15:0] note, // the note or delay that currently needs to be processed

    output play_enable, // allows chord_player to control the note_players directly, only high during advance state when play is high
    output note_done, // overrides the note_done from note_player because we can now have notes ending at different
                      // places
    output [15:0] note_0, // the last six are inputs to three parallel note_players to play chords
    output [15:0] note_1,
    output [15:0] note_2,
    output load_new_note_0,
    output load_new_note_1,
    output load_new_note_2
);
  wire [5:0] state;
  reg [5:0] next_state;
  // holds the chord FSM  state
  dff #(6) state_reg(.clk(clk), .d(next_state), .q(state));


  reg [15:0] cur_note_0, cur_note_1, cur_note_2;
  wire [15:0] stored_note_0, stored_note_1, stored_note_2;
  // might only have to store duration, but for now we'll keep the whole note
  dff #(16) note_0_reg(.clk(clk), .d(note_0), .q(stored_note_0));
  dff #(16) note_1_reg(.clk(clk), .d(note_1), .q(stored_note_1));
  dff #(16) note_2_reg(.clk(clk), .d(note_2), .q(stored_note_2));


  wire [15:0] note_to_load;
  // this gives us a cycle to determine what to do with the note being passed in, LOAD_X states use note_to_load
  // its possible that we could avoid this if the note inputs from song_reader are static for each clock cycle, but we keep it for robustness
  dff #(16) load_note_reg(.clk(clk), .d(note), .q(note_to_load));


  wire [5:0] next_count, count;
  // counter for playing the chord for the correct duration
  dff #(6) counter_reg(.clk(clk), .d(next_count), .q(count));


  always @(*) begin
    casex({rst, state})
      {1'b1, 6'bXXXXXX}: next_state = `LOAD; // all outputs will be set to 0 and next_state will be LOAD on rst

                     // if new_note and note is not a delay, try to place it in note_0, then note_1, and then note_2. If none of them are open, drop the note and stay in LOAD
                     // if new_note and note is a delay, set the duration and then play the chord.
                     // if not new_note, stay in LOAD
      {1'b0, `LOAD}: next_state = (new_note) ? ((note[15] == 0) ? ((stored_note_0[8:3] == 6'd0) ? `LOAD_0
                                                                                                : ((stored_note_1[8:3] == 6'd0) ? `LOAD_1
                                                                                                                                : ((stored_note_2[8:3] == 6'd0) ? `LOAD_2 : `LOAD)
                                                                                                  )
                                                                  )
                                                                : `SET_DURATION) 
                                             : `LOAD; 
      {1'b0, `LOAD_0}: next_state = `LOAD; // after loading a particular note_player go back to main load state
      {1'b0, `LOAD_1}: next_state = `LOAD;
      {1'b0, `LOAD_2}: next_state = `LOAD;
      {1'b0, `SET_DURATION}: next_state = `PLAY_CHORD; // once we've been given a delay block, we want to first set the counter and update our note durations while the 
                                                       // delay value is still available in the register, then move onto playing the chord for the counters duration
      {1'b0, `PLAY_CHORD}: next_state = (count == 1'b0) ? `LOAD : `PLAY_CHORD; // play the chord until the counter reaches 0
      default: next_state = `LOAD;
    endcase
  end
  
  // assign note outputs to be 0 on rst
  // assign note outputs to be note_to_load when the current state is the note_players corresponding LOAD_X state
  // assign note outputs to update their duration with negative checking when we are in the SET_DURATION state because there we have the current delay blocks duration
  // otherwise assign note outputs to hold their value  
  assign note_0 = (rst) ? 16'd0 : ((state == `LOAD_0) ? note_to_load 
                                                      : ((state == `SET_DURATION) ? ((stored_note_0[8:3] <= note_to_load[8:3]) ? {stored_note_0[15:9], 6'd0, stored_note_0[2:0]} 
                                                                                                                          : {stored_note_0[15:9], stored_note_0[8:3]-note_to_load[8:3], stored_note_0[2:0]}) 
                                                                                  : stored_note_0));
  assign note_1 = (rst) ? 16'd0 : ((state == `LOAD_1) ? note_to_load 
                                                      : ((state == `SET_DURATION) ? ((stored_note_1[8:3] <= note_to_load[8:3]) ? {stored_note_1[15:9], 6'd0, stored_note_1[2:0]} 
                                                                                                                          : {stored_note_1[15:9], stored_note_1[8:3]-note_to_load[8:3], stored_note_1[2:0]}) 
                                                                                  : stored_note_1));
  assign note_2 = (rst) ? 16'd0 : ((state == `LOAD_2) ? note_to_load 
                                                      : ((state == `SET_DURATION) ? ((stored_note_2[8:3] <= note_to_load[8:3]) ? {stored_note_2[15:9], 6'd0, stored_note_2[2:0]} 
                                                                                                                          : {stored_note_2[15:9], stored_note_2[8:3]-note_to_load[8:3], stored_note_2[2:0]}) 
                                                                                  : stored_note_2));
  
  // only tell note_players to load a new note when the current state is the note_players corresponding LOAD_X state
  assign load_new_note_0 = (rst) ? 1'd0 : ((state == `LOAD_0) ? 1'b1 : 1'b0);
  assign load_new_note_1 = (rst) ? 1'd0 : ((state == `LOAD_1) ? 1'b1 : 1'b0);
  assign load_new_note_2 = (rst) ? 1'd0 : ((state == `LOAD_2) ? 1'b1 : 1'b0);
  
  // tell song_reader to send a new note only when we are ready within the main LOAD state
  assign note_done = (rst) ? 1'd0 : ((state == `LOAD) ? 1'b1 : 1'b0);
  
  // only send the play signal to the note players when we are in the PLAY_CHORD state 
  assign play_enable = (rst) ? 1'd0 : ((state == `PLAY_CHORD) ? play : 1'b0);

  // load the counter value when we are in the SET_DURATION state, then decrement counter when we are in the PLAY_CHORD state and beat and play are both high, 
  // otherwise counter holds its value
  assign next_count = (rst) ? 1'd0 : ((state == `SET_DURATION) ? note_to_load[8:3] : ((state == `PLAY_CHORD && beat && play) ? count - 1 : count));
endmodule