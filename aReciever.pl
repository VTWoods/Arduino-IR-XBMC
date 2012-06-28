#!/usr/bin/perl

use warnings;
use strict;
use Device::SerialPort;
use Time::HiRes qw(usleep);

use IO::Socket::INET;

#Get how long the high byte from the reading
sub get_high_byte {
  my $microseconds = shift;
  my $value = ($microseconds * 256) / 15625;

  $value = $value / 256;

  return $value;
}

#Get the low byte from the reading
sub get_low_byte {
  my $microseconds = shift;
  
#  my $value = ($microseconds * 16384) / 1000000;
  my $value = ($microseconds * 256) / 15625;

  $value = $value % 256;

  return $value;
}

#encode arduino's messages for a message to LIRC
sub encode_msg {
    my @in_msg = @_;
    my $out_msg = "";
    my $toggle = 1;
    #Work in byte mode
    use bytes;
    foreach(@in_msg)
    {
	my $reading = $_;
	my $low = get_low_byte($reading);
	my $high = get_high_byte($reading);
	if($toggle eq 1)
	{
	    $toggle = 0;
	    $high = $high | 0x080;
	}
	else
	{
	    $toggle = 1;
	}
	#message should be how long the low signal was combined with the high signal
	$out_msg .= chr($low) . chr($high);
	
    }
    no bytes;
    
    return $out_msg;
}
my $device = "/dev/ttyACM0";
if($ARGV[0])
{
    $device = $ARGV[0];
}
my $port = Device::SerialPort->new($device);
$port->baudrate(115200);
$port->databits(8);
$port->parity("none");
$port->stopbits(1);
while(1)
{
    my $total = 0;
    my @reading = [];
    #We should get 52 signals
    while($total != 52)
    {
	my $final = "";
	my ($saw1, $saw, $saw2);
	my $count = 0;
	#Sit and read while we wait on the arduino to message us
	while($count == 0)
	{
	    ($count, $saw1)=$port->read(1);
	    if($count == 0)
	    {
		usleep(1000);

	    }
	}
	#Wait for the second message
	$count = 0;
	while($count == 0)
	{
	    ($count,$saw2)=$port->read(1);
	    if($count == 0)
	    {
		usleep(1000);

	    }
	}

	#unpack the 16 bit integer
	$saw = $saw1 . $saw2;
	$reading[$total] = unpack("n*",$saw);
	$total++;
    }
    #Get ready to send this to LIRC
    my $socket = new IO::Socket::INET->new(PeerPort=>8765,
					   Proto=>'udp',
					   PeerAddr=>'localhost',Broadcast=>1) or die "Can't bind : $@\n";

    my $enc_msg = encode_msg(@reading);
    $socket->send($enc_msg);
    
    $socket->close();
}
