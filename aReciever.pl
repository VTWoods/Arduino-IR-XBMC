#!/usr/bin/perl

use warnings;
use strict;
use Device::SerialPort;
use Time::HiRes qw(usleep);

use IO::Socket::INET;

sub get_high_byte {
  my $microseconds = shift;
  
#  my $value = ($microseconds * 16384) / 1000000;
  my $value = ($microseconds * 256) / 15625;

  $value = $value / 256;

  return $value;
}

sub get_low_byte {
  my $microseconds = shift;
  
#  my $value = ($microseconds * 16384) / 1000000;
  my $value = ($microseconds * 256) / 15625;

  $value = $value % 256;

  return $value;
}

sub encode_msg {
    my @in_msg = @_;
    #my $in = shift;
    my $out_msg = "";
    my $toggle = 1;
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
    while($total != 52)
    {
	my $final = "";
	#my $saw = $port->lookfor();
	my ($saw1, $saw, $saw2);
	my $count = 0;
	while($count == 0)
	{
	    ($count, $saw1)=$port->read(1);
	    if($count == 0)
	    {
		usleep(1000);

	    }
	}
	$count = 0;
	while($count == 0)
	{
	    ($count,$saw2)=$port->read(1);
	    if($count == 0)
	    {
		usleep(1000);

	    }
	}

	$saw = $saw1 . $saw2;
	$reading[$total] = unpack("n*",$saw);
	$total++;
    }
    my $socket = new IO::Socket::INET->new(PeerPort=>8765,
					   Proto=>'udp',
					   PeerAddr=>'localhost',Broadcast=>1) or die "Can't bind : $@\n";

    my $enc_msg = encode_msg(@reading);
    $socket->send($enc_msg);
    
    $socket->close();
}
