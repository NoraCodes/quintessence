-- Tuning

local tuning = {}

tuning.FREQ_A4 = 440
tuning.NOTE_A4 = 69
tuning.TWELFTH_ROOT_OF_2 = 2^(1/12)

function tuning.midi_note_to_freq(note)
  return FREQ_A4 * (TWELFTH_ROOT_OF_2 ^ (note - NOTE_A4))
end

return tuning

