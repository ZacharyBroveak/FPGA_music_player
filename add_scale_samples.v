module add_scale_samples(
    input [15:0] sample_0, // samples from the three parallel note_players
    input [15:0] sample_1,
    input [15:0] sample_2,
    input done_with_note_0, // we use the note_done outputs from the note_players to determine which samples to include and how to scale them
                            // we can also reuse done_with_note and new_sample_ready for determining whether to include different harmonics modules
                            // in the final sample because harmonics just take the same duration as the note itself and are loaded in sync
    input done_with_note_2,
    input done_with_note_1,
    input new_sample_ready_0, // we use ready signals to determine chord_sample_ready
    input new_sample_ready_1,
    input new_sample_ready_2,
    input [47:0] harmonics_0, // concatenated overtone samples from the harmonics of each note in the chord
    input [47:0] harmonics_1,
    input [47:0] harmonics_2,

    output reg [15:0] chord_sample, // final sample and ready outputs go to codec
    output chord_sample_ready
); 
  // intermediate wires that will be used to determine chord_sample within mux
  wire signed [15:0] note_0_combined, note_1_combined, note_2_combined, note_01_combined, note_02_combined, note_12_combined, note_012_combined;

  // combine notes using signed shifting in order to avoid amplitude cutoff and ensure proper scaling
  assign note_0_combined = ($signed(sample_0)>>>1) + ($signed(harmonics_0[15:0])>>>1) + ($signed(harmonics_0[31:16])>>>1) + ($signed(harmonics_0[47:32])>>>1);
  assign note_1_combined = ($signed(sample_1)>>>1) + ($signed(harmonics_1[15:0])>>>1) + ($signed(harmonics_1[31:16])>>>1) + ($signed(harmonics_1[47:32])>>>1);
  assign note_2_combined = ($signed(sample_2)>>>1) + ($signed(harmonics_2[15:0])>>>1) + ($signed(harmonics_2[31:16])>>>1) + ($signed(harmonics_2[47:32])>>>1);
  assign note_01_combined = (note_0_combined>>>1) + (note_1_combined>>>1);
  assign note_02_combined = (note_0_combined>>>1) + (note_2_combined>>>1);
  assign note_12_combined = (note_1_combined>>>1) + (note_2_combined>>>1);
  assign note_012_combined = (note_0_combined/3) + (note_1_combined/3) + (note_2_combined/3); // this will introduce a delay we may have to pipeline

  // chord_sample assignment mux
  always @(*) begin
      casex({done_with_note_2, done_with_note_1, done_with_note_0}) // select the appropriate chord_sample depending on which notes are not yet done
          3'b000: chord_sample = note_012_combined; // play_enable is high, assign chord_sample the appropriate combination of notes
          3'b001: chord_sample = note_12_combined;
          3'b010: chord_sample = note_02_combined;
          3'b011: chord_sample = note_2_combined;
          3'b100: chord_sample = note_01_combined;
          3'b101: chord_sample = note_1_combined;
          3'b110: chord_sample = note_0_combined;
          3'b111: chord_sample = chord_sample;
          default: chord_sample = chord_sample;
      endcase
  end

  // final sample is ready anytime one of the note_player samples are ready
  assign chord_sample_ready = new_sample_ready_0 | new_sample_ready_1 | new_sample_ready_2;
endmodule

