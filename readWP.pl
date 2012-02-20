use strict;
use warnings;
# mit cookies: http://perlmeme.org/tutorials/lwp.html
# http://www.perlmonks.org/?node_id=74015
use LWP;
use HTTP::Cookies;

my $url_timeout = 40;
my $output_file = "f:\\Users\\d-nnis\\reapWP_output.html";
my $cookie_file = "f:\\Users\\d-nnis\\reapWP_cookie.txt";
my $login_url = "http://web6.codeprobe.de/wikka/UserSettings";
my $url2 = "http://web6.codeprobe.de/wikka/SammLung";
my %config = File::readfile("..\\_excl\\login.csv",'config');
my $uname = $config{uname};
my $pwd = $config{pwd};

my $ua = LWP::UserAgent->new();
$ua->cookie_jar(HTTP::Cookies->new(file => "$cookie_file", autosave => 1));
$ua->timeout($url_timeout);
my $request = HTTP::Request->new('GET', "$login_url");
my $response = $ua->request($request);

## login
$response = $ua->post($login_url,['name'=>$uname,'password'=>$pwd,'login'=>"anmelden",'Referer' =>$login_url]);

writefile($output_file, $response->content);

$ua->cookie_jar->extract_cookies($response);

## SammLung
$request = HTTP::Request->new('GET', $url2);

$response = $ua->request($request);

if ($response->is_error()) {
    $response = $response->status_line;
    exit;
} else {
	print $response->content;
	writefile($output_file, $response->content);
}

my $pageURL="http://www.web6.codeprobe.de/wikka/SammLung";










sub writefile {
	my $file = shift;
	#my @lines = @_[1 .. $#_];	# alle Elemente 1 bis Ende
	my @lines = @_;	# alle Elemente 1 bis Ende
	print "write file ", $file;
	if (!open (WFILE, '>', $file) ) {
		print "\n!!! Achtung: Kann $file nicht oeffnen: $!\nNeuer Versuch Tastendruck";
		while (<STDIN> eq '') {}
		writefile($file, @lines);
	}
	open (WFILE, '>', $file);
	print WFILE @lines;
	print " lines: ", scalar @lines, ".\n";
	close WFILE;
}
