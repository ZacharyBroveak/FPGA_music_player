//
//  music_player module
//
//  This music_player module connects up the MCU, song_reader, chord_player,
//  harmonics, note_player, add_and_scale_samples, beat_generator, and codec_conditioner.
//

module music_player(
    // Standard system clock and reset
    input clk,
    input reset,

    // Our debounced and one-pulsed button inputs.
    input play_button,
    input next_button,

    // The raw new_frame signal from the ac97_if codec.
    input new_frame,

    // This output must go high for one cycle when a new sample is generated.
    output wire new_sample_generated,

    // Our final output sample to the codec. This needs to be synced to
    // new_frame.
    output wire [15:0] sample_out,
    output wire [5:0] curr_note,
   
    output wire new_display_note,

    input wire ps2_clk,
    input wire ps2_data,
    input wire ps2_reset
);
    // The BEAT_COUNT is parameterized so you can reduce this in simulation.
    // If you reduce this to 100 your simulation will be 10x faster.
    parameter BEAT_COUNT = 100;

//
//  ****************************************************************************
//      Master Control Unit
//  ****************************************************************************
//
 
    wire play;
    wire reset_player;
    wire [1:0] current_song;
    wire song_done;
    mcu mcu(
        .clk(clk),
        .reset(reset),
        .play_button(play_button),
        .next_button(next_button),
        .play(play), // output
        .reset_player(reset_player), // output
        .song(current_song), // output
        .song_done(song_done) // input
    );

//
//  ****************************************************************************
//      Song Reader
//  ****************************************************************************
//
    wire [15:0] note_to_play;
    wire new_note;
    wire note_done;
    song_reader song_reader(
        .clk(clk),
        .reset(reset | reset_player),
        .play(play), // input
        .song(current_song), // input
        .song_done(song_done), // output
        .note(note_to_play), // output
        .new_note(new_note), // output
        .note_done(note_done) // input
    );

//  
//  ****************************************************************************
//      Chord Player
//  ****************************************************************************
//  
    wire beat;
    wire play_enable, load_new_note_0, load_new_note_1, load_new_note_2;
    wire [15:0] note_0, note_1, note_2;
    chord_player chord_player(
        // inputs
        .clk(clk),
        .rst(reset),
        .play(play),
        .beat(beat),
        .new_note(new_note),
        .note(note_to_play),

        //outputs
        .play_enable(play_enable),
        .note_done(note_done),
        .note_0(note_0),
        .note_1(note_1),
        .note_2(note_2),
        .load_new_note_0(load_new_note_0),
        .load_new_note_1(load_new_note_1),
        .load_new_note_2(load_new_note_2)
    );
   
    assign new_display_note = new_note | keyboard_new_note;

    // curr_note should be the root of the chord or the keyboard note
    // FIXED: Swapped ternary logic to display keyboard_note when keyboard_play is active
    assign curr_note = keyboard_play ? keyboard_note : note_0[14:9];

//  
//  ****************************************************************************
//      Harmonics
//  ****************************************************************************
//  
    wire [47:0] harmonics_sample_0, harmonics_sample_1, harmonics_sample_2;
    harmonics harmonics_0(
      .clk(clk),
      .rst(reset),
      .play_enable(play_enable),
      .beat(beat),
      .generate_next_sample(generate_next_sample),
      .load_new_note(load_new_note_0),
      .duration_to_load(note_0[8:3]),
      .note_to_load(note_0[14:9]),  
      .harmonics(harmonics_sample_0)
    );

    harmonics harmonics_1(
      .clk(clk),
      .rst(reset),
      .play_enable(play_enable),
      .beat(beat),
      .generate_next_sample(generate_next_sample),
      .load_new_note(load_new_note_1),
      .duration_to_load(note_1[8:3]),
      .note_to_load(note_1[14:9]),  
      .harmonics(harmonics_sample_1)
    );

    harmonics harmonics_2(
      .clk(clk),
      .rst(reset),
      .play_enable(play_enable),
      .beat(beat),
      .generate_next_sample(generate_next_sample),
      .load_new_note(load_new_note_2),
      .duration_to_load(note_2[8:3]),
      .note_to_load(note_2[14:9]),  
      .harmonics(harmonics_sample_2)
    );

//  
//  ****************************************************************************
//      Note Players
//  ****************************************************************************
//  
    wire generate_next_sample, generate_next_sample0;

    dffr pipeline_ff_gen_next_sample (.clk(clk), .r(reset), .d(generate_next_sample0), .q(generate_next_sample));

    wire done_with_note_0, new_sample_ready_0;
    wire [15:0] sample_out_0;
    note_player note_player_0(
        .clk(clk),
        .reset(reset),
        .play_enable(play_enable),
        .note_to_load(note_0[14:9]),
        .duration_to_load(note_0[8:3]),  
        .load_new_note(load_new_note_0),
        .done_with_note(done_with_note_0),
        .beat(beat),
        .generate_next_sample(generate_next_sample),
        .sample_out(sample_out_0),
        .new_sample_ready(new_sample_ready_0)
    );

    wire done_with_note_1, new_sample_ready_1;
    wire [15:0] sample_out_1;
    note_player note_player_1(
        .clk(clk),
        .reset(reset),
        .play_enable(play_enable),
        .note_to_load(note_1[14:9]),
        .duration_to_load(note_1[8:3]),  
        .load_new_note(load_new_note_1),
        .done_with_note(done_with_note_1),
        .beat(beat),
        .generate_next_sample(generate_next_sample),
        .sample_out(sample_out_1),
        .new_sample_ready(new_sample_ready_1)
    );

    wire done_with_note_2, new_sample_ready_2;
    wire [15:0] sample_out_2;
    note_player note_player_2(
        .clk(clk),
        .reset(reset),
        .play_enable(play_enable),
        .note_to_load(note_2[14:9]),
        .duration_to_load(note_2[8:3]),  
        .load_new_note(load_new_note_2),
        .done_with_note(done_with_note_2),
        .beat(beat),
        .generate_next_sample(generate_next_sample),
        .sample_out(sample_out_2),
        .new_sample_ready(new_sample_ready_2)
    );

//  
//  ****************************************************************************
//      Add and Scale Sample Logic
//  ****************************************************************************
//  
    wire [15:0] chord_sample, next_chord_sample;
    wire chord_sample_ready, next_chord_sample_ready;
    add_scale_samples add_scale_samples(
      .sample_0(sample_out_0),
      .sample_1(sample_out_1),
      .sample_2(sample_out_2),
      .done_with_note_0(done_with_note_0),
      .done_with_note_1(done_with_note_1),
      .done_with_note_2(done_with_note_2),
      .new_sample_ready_0(new_sample_ready_0),
      .new_sample_ready_1(new_sample_ready_1),
      .new_sample_ready_2(new_sample_ready_2),
      .harmonics_0(harmonics_sample_0),
      .harmonics_1(harmonics_sample_1),
      .harmonics_2(harmonics_sample_2),
      .chord_sample(next_chord_sample),
      .chord_sample_ready(next_chord_sample_ready)
    );

    dffr #(.WIDTH(16)) pipeline_ff_note_sample (.clk(clk), .r(reset), .d(next_chord_sample), .q(chord_sample));
    dffr pipeline_ff_new_sample_ready (.clk(clk), .r(reset), .d(next_chord_sample_ready), .q(chord_sample_ready));

//  
//  ****************************************************************************
//      Echo
//  ****************************************************************************
//  
    wire [15:0] final_echoed_sample;
    wire final_echo_ready;
   
    assign final_echo_ready = chord_sample_ready;

    echo global_echo (
        .clk(clk),
        .reset(reset),
        .play_enable(play),
        .echo_attenuator(4'd1),            
        .delay(15'd500),                  
        .generate_next_sample(chord_sample_ready),
        .dynamics_sample(chord_sample),      
        .base_sample(final_echoed_sample)    
    );

//  
//  ****************************************************************************
//      Keyboard Signal Receiver
//  ****************************************************************************
//  
    wire keyboard_new_note;
    wire keyboard_play;
    wire [5:0] keyboard_duration;
    wire [5:0] keyboard_note;
   
    keyboard_reader keyboard_reader_device(
        .clk(clk),
        .reset(reset | reset_player),
        // FIXED: Re-applied the logic from your working file so the keyboard turns off during playback
        .enabled(!play),
        .note_done_pulse(note_done),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .ps2_reset(ps2_reset),
        .new_note_pulse(keyboard_new_note),
        .keyboard_play(keyboard_play),
        .duration(keyboard_duration),
        .note(keyboard_note)
    );

    wire note_done_kb;
    // FIXED: Split wire declaration properly and removed generate_next_sample_kb
    wire [15:0] note_sample_kb;
    wire note_sample_ready_kb;

    note_player note_player(
        .clk(clk),
        .reset(reset),
        .play_enable(1'b1),
        .note_to_load(keyboard_note),
        .duration_to_load(keyboard_duration),
        .load_new_note(keyboard_new_note),
        .done_with_note(note_done_kb),
        .beat(beat),
        // FIXED: Connected to the global generate_next_sample signal instead of a floating wire
        .generate_next_sample(generate_next_sample),
        .sample_out(note_sample_kb),
        .new_sample_ready(note_sample_ready_kb)
    );

//  
//  ****************************************************************************
//      Codec Conditioner
//  ****************************************************************************
//  
    wire new_sample_generated0;
    wire [15:0] mp_sample_out;

    assign new_sample_generated0 = generate_next_sample;
    codec_conditioner codec_conditioner(
        .clk(clk),
        .reset(reset),
        .new_sample_in(keyboard_play ? note_sample_kb : final_echoed_sample),
        // FIXED: Multiplexed the latch signal so the codec knows when a keyboard sample is actually ready
        .latch_new_sample_in(keyboard_play ? note_sample_ready_kb : final_echo_ready),
        .generate_next_sample(generate_next_sample0),
        .new_frame(new_frame),
        .valid_sample(mp_sample_out)
    );

    dffr pipeline_ff_nsg (.clk(clk), .r(reset), .d(new_sample_generated0), .q(new_sample_generated));
    assign sample_out = mp_sample_out;

  //  
  //  ****************************************************************************
  //      Beat Generator
  //  ****************************************************************************
  //  
      beat_generator #(.WIDTH(10), .STOP(BEAT_COUNT)) beat_generator(
          .clk(clk),
          .reset(reset),
          .en(generate_next_sample),
          .beat(beat)
      );

endmodule