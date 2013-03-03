# this is bullshit data, just for testing syntax

@x_range = (-1..1);		# +x -> North
@y_range = (-1..1);		# +y -> East
@z_range = (-1..1);		# +z -> up ... ?? or should we follow right hand rule??

$x_ant = 0;			# where antenna is located in above interval
$y_ant = 0;
$z_ant = 0;

$x_step = 0.2;			# x interval per voxel in m
$y_step = 0.2;
$z_step = 0.2;

$lambda = 3e8 / 1575e6 ;	# wave lenght 300000000/1575000000
$dB1 = 30;			# dB value which is mapped to 1
$scale = 0.001;		# rescaler to avoid numerical overflow etc
