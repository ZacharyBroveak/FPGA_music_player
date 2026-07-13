module harmonics (
  input clk,
  input rst,
  
  input play_enable, // standard note_player inputs, passed directly
  input beat,
  input generate_next_sample,
  input load_new_note,
  input [5:0] duration_to_load, 
  input [5:0] note_to_load,  // this will be used as the fundamental, multiples of it will determine harmonics

  output [47:0] harmonics // concatenation of the three harmonic components produced
);
  // intermediate wires to do harmonics computation and scaling, then assemble harmonics output
  wire [15:0] second_harmonic_sample, third_harmonic_sample, fourth_harmonic_sample;
  wire signed [15:0] sample_out_h2, sample_out_h3, sample_out_h4;
  wire [6:0] second_harmonic_temp, third_harmonic_temp, fourth_harmonic_temp;
  wire [5:0] second_harmonic, third_harmonic, fourth_harmonic;

  assign second_harmonic_temp = note_to_load + 6'd12; // 2nd harmonic is 12 semitones up
  assign third_harmonic_temp = note_to_load + 6'd19; // 3rd harmonic is 19 semitones up 
  assign fourth_harmonic_temp = note_to_load + 6'd24; // 4th harmonic is 24 semitones up 

  // check for overflow, if it occurs, back up the fundamental to ensure tonal quality
  assign second_harmonic = (second_harmonic_temp[6] == 1'd1) ? note_to_load : second_harmonic_temp; 
  assign third_harmonic = (third_harmonic_temp[6] == 1'd1) ? note_to_load : third_harmonic_temp;
  assign fourth_harmonic = (fourth_harmonic_temp[6] == 1'd1) ? note_to_load : fourth_harmonic_temp;

  // second harmonic note_player
  note_player note_player_h2(
        .clk(clk),
        .reset(rst),
        .play_enable(play_enable), // inputs
        .note_to_load(second_harmonic), 
        .duration_to_load(duration_to_load),  
        .load_new_note(load_new_note), 

        .done_with_note(), // output
        .beat(beat), // input
        .generate_next_sample(generate_next_sample), // input
        .sample_out(sample_out_h2), // output
        .new_sample_ready() // output
  );

  // third harmonic note_player
  note_player note_player_h3(
        .clk(clk),
        .reset(rst),
        .play_enable(play_enable), // inputs
        .note_to_load(third_harmonic), 
        .duration_to_load(duration_to_load),  
        .load_new_note(load_new_note), 

        .done_with_note(), // output
        .beat(beat), // input
        .generate_next_sample(generate_next_sample), // input
        .sample_out(sample_out_h3), // output
        .new_sample_ready() // output
  );

  // fourth harmonic note_player
  note_player note_player_h4(
        .clk(clk),
        .reset(rst),
        .play_enable(play_enable), // inputs
        .note_to_load(fourth_harmonic), 
        .duration_to_load(duration_to_load),  
        .load_new_note(load_new_note), 

        .done_with_note(), // output
        .beat(beat), // input
        .generate_next_sample(generate_next_sample), // input
        .sample_out(sample_out_h4), // output
        .new_sample_ready() // output
  );
  // scale overtones in order to achieve desire harmonic quality
  // second harmonic * 0.5, third harmonic * 0.25, fourth harmonic * 0.125, or exponential decay of harmonics, provides a warm synth-like sound
  assign second_harmonic_sample = sample_out_h2>>>1;
  assign third_harmonic_sample = sample_out_h3>>>2;
  assign fourth_harmonic_sample = sample_out_h4>>>3;
  
  // output
  assign harmonics = {fourth_harmonic_sample, third_harmonic_sample, second_harmonic_sample};
endmodule