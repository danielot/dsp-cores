% Generates NIF file for SIN and COS dds

bit_width = 16

freq_num = 52;
freq_den = 203;

sin_filename = 'dds_sin.coe'
cos_filename = 'dds_cos.coe'
phase_points = 1;

n = 0 : freq_den-1;

%calculate corresponding phases
phase_range = [0 2*pi]; %closed at left, open at right extreme
phase_step = (phase_range(2)-phase_range(1))/phase_points;
phases = phase_range(1) : phase_step : phase_range(2)-phase_step;


memsize = freq_den*phase_points;

sin_mat = []; cos_mat = [];

for phase = phases
    sin_value = -sin(2*pi*freq_num/freq_den*n + phase)*(1-2^-bit_width);
    cos_value = cos(2*pi*freq_num/freq_den*n + phase)*(1-2^-bit_width);
    sin_mat = [sin_mat ; sin_value];
    cos_mat = [cos_mat ; cos_value];
end
    
sin_fixed = sfi(sin_mat,bit_width,bit_width-1);
cos_fixed = sfi(cos_mat,bit_width,bit_width-1);

sinID = fopen(sin_filename,'w');
cosID = fopen(cos_filename,'w');

% must be a loop (not a simple fprintf) because of the hex function
fprintf(sinID, 'memory_initialization_radix=16;\r\nmemory_initialization_vector=\r\n')
fprintf(cosID, 'memory_initialization_radix=16;\r\nmemory_initialization_vector=\r\n')

for index = 1: memsize-1,
 fprintf(sinID,'%04s,\r\n', hex(sin_fixed(index)));
 fprintf(cosID,'%04s,\r\n', hex(cos_fixed(index)));
end

% last element does not have a comma
fprintf(sinID,'%04s\r\n', hex(sin_fixed(memsize)));
fprintf(cosID,'%04s\r\n', hex(cos_fixed(memsize)));