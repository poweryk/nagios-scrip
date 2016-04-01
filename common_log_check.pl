#!/usr/bin/perl
use strict;
use JSON;
use Data::Dumper;
use Encode;
#my $LogPath='/tmp/';
my $LogPath='/root/logs/';
my ($sec,$min0,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime();
$year=$year+1900;
$mon=$mon+1;
$mon="0$mon" if ($mon =~ m/^[\d]$/);
my $min=$min0;
$min0="0$min0" if ($min0 =~ m/^[\d]$/);
$mday="0$mday" if ($mday =~ m/^[\d]$/);
my $timeNow="$year-$mon-$mday $hour:$min0";
my $Ctimes=2;
my $Cmin=25;
my $date="$year-$mon-$mday";
my $UTC=`date +%s -d '$year-$mon-$mday $hour:$min0:$sec'`;
chomp $UTC;
if (!@ARGV){
	print "must input config file and check type!";
	exit 3;
}
my $Files=shift;
if(!-e $Files){
	print "config file not exsist!~";
	exit 3;
}
my $type=shift;
my ($output,$CheckType,$file)=&init($Files);
my %CheckType   =%$CheckType;
my %file=%$file;
my %output=%$output;
if(!$type){
	print "please input check type:" ;
	foreach my $key (keys %CheckType){
		print $key.";";
	}
	exit 3;
}
my @Keys=@{$CheckType{$type}};
my $FileType=shift @Keys;
my $lines=shift @Keys;
my $File=$LogPath.$file{$FileType};
$Ctimes=shift @Keys;
$Cmin=shift @Keys;
if(!exists $CheckType{$type}){
	print "please input check type:" ;
	foreach my $key (keys %CheckType){
		print $key.";";
	}
	exit 3;
}
my $len=@Keys;
unless(-e $File){
	print "$File not exsit,means no error !";
	exit 0;	
}
my @check_time= &grep_time($Cmin,$UTC);
my %result=&parser_Error_log(\@check_time,$File);
my $flag=3;
my $all=0;
if (%result){
	my %Return=&output();
	foreach my $Key (keys %result){
		print "FILE:$file{$FileType},";
		print "$Return{$Key}," if ($Return{$Key}); 
		print "error $result{$Key} times in $Cmin mins;";
		$flag=2;	
	}
}
my $exit=3;
if (!%result){
	print "CheckType:$type,FILE:$file{$FileType} status look ok!|";
	exit 0;
}
elsif ($flag==2){
	$exit=2;
}
else{
	print "$file{$FileType} log status unkown!|";
	$exit=1;
}
#foreach my $Keys (keys %result){
#	print "In $Cmin mins Error "."\"". $Keys."\""." repeat $result{$Keys} times;\n" ;#if ($result{$Keys}>=10);
#	}
$exit=2 if ($type eq 'test');
exit $exit;
#
sub parser_Error_log{
	my $arr=shift;
	my $log=shift;
	my %hash=();
	if (!-e $log){
		print "$log not exists!";
		exit 3;
	}
	else{
	for my $keys(@Keys){
		my $a=0;
		for my $keys1(@$arr){
			chomp $keys1;
			my $c=0;
		       	$c=`grep "$keys" $log|grep '$keys1'|wc -l`;	
#|grep $keys| wc -l`;
#egrep '^$_'|wc -l`;
	       	chomp $c;
		$a+=$c;
		}
		if ($a>=$Ctimes){
		$hash{$keys}=$a;
		--$len;	
		}
	}
	}
	return %hash;
}
sub grep_time{
         my $times=shift;
         my $Now=shift;
         my @check_time=();
         for(my $i=0;$i<$times;$i++){
                $Now=($Now-60);
                my $str=`date -d '1970-01-01 UTC $Now seconds' +'%Y-%m-%d %H:%M'`;
                chomp $str; 
		push @check_time,"$str";
         }
 return @check_time;

}
sub output{
        my $error_lines="";
        my $num=0;
        my $time="No matched Time";
#2016-02-22 09:22:27:XQBTransferOut_FAIL_9
        foreach my $key(keys %result){
                my $msg="No Chinese Info!";
                $msg=$output{$key} if (exists $output{$key});
                $error_lines=`cat -n $File |grep '$key' |egrep '.*[0-9].*$key'|tail -n 1`;
                chomp $error_lines;
		# 83  2016-02-24 10:34:04,974|pool-2-thr
                if ($error_lines=~ m/^\s*([\d]+)\s*([\d\-]+\s+[\d]+\:[\d]+\:[\d]+)[,\:\|](.*)/){
                $time=$2 if ($2);
                $num=$1 if ($1);
                if($3){
                $error_lines="$2,$3" ;}
                else {

                        $error_lines="$2";
                }
                        }
                if($lines==1){
                        $output{$key}="Line:$num,TIME:$time;$key;$msg:$error_lines";
                        }
                elsif($lines==0) {
                        $output{$key}="Line:$num,TIME:$time,MSG:$msg";
                }
                elsif($lines==2) {
                        my $UTC1=`date +%s -d '$time'`;
                        chomp $UTC1;
                        if (($UTC-$UTC1)>60){                           
                        $output{$key}="Line:$num,CHECK TIME:$timeNow,TIMENOW:$time;$key;$msg";
                        }
                }
                elsif($lines==10){
                        my $x=$lines+1;
                        my $flag=0;
                        my $Context=`cat -n $File |grep -A $lines '$key' |tail -n $x`;
                        chomp $Context;
                        my $ContextLine="";
                        my @m = split /\n/,$Context;
                        foreach  (@m){
                                chomp;
                                if ($_ =~ m/.*$key.*/){
                                        $_=~m/^\s*[\d]+\s*(.*?)\,.*\|.*/;
                                        $time=$1;
                                        $flag=1;
                                  }
                                if ($flag==1){
                                        $_=~ m/^\s+([\d]+)\s*(.*)/;
                                        $num=$1 if ($num==0);
                                        $ContextLine.="$2\n";
                                 }
                        }
                      $output{$key}="Line=$num;TIME:$time;$output{$key}\n"."Log:\n".$ContextLine."\n" if ($num!=0);
                }

        }
        return %output;

}
sub init{
	my $configFile=shift;
	my %config;
	my $logfiles;
	my $msg;
	my $checktype;
	my $date="$year-$mon-$mday";
	open (FILE,"$configFile") or die $!; 
	while (<FILE>){
	        chomp $_; 
	        utf8::encode($_);
	        if ($_=~ m/(.*?)=(.*)/){
	                $config{$1}=$2;
	        }   
	}
	close FILE;
	$msg=decode_json($config{'msg'});
	$checktype=decode_json($config{'checktype'});
	$logfiles=decode_json($config{'filename'});
	for my $key(keys %$logfiles){
	        if ($$logfiles{$key}=~m/date/){
	                $$logfiles{$key}=~s/date/$date/g;
	        }
	}

	return ($msg,$checktype,$logfiles);


}
