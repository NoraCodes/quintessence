-- Tuning

FREQ_A4 = 440
NOTE_A4 = 69
TWELFTH_ROOT_OF_2 = 2^(1/12)

function midi_note_to_freq(note)
  return FREQ_A4 * (TWELFTH_ROOT_OF_2 ^ (note - NOTE_A4))
end