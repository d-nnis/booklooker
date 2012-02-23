use strict;
use warnings;
use Essent_BL;
use WWW::Mechanize;
use HTTP::Cookies;
use feature qw/switch/;
use HTML::PullParser;
use HTML::TokeParser;
use base qw(HTML::Parser);
use utf8;
no utf8;
use Encode;
use URI::Escape;

my %config = File::readfile("..\\_excl\\login.csv",'config');

##################
package main;
##################

my $url = "http://www.booklooker.de/";
my $url_login = "http://www.booklooker.de/app/sec/login.php";
my $output_file = "f:\\Users\\d-nnis\\reapWP_output.html"; 
my $cookie_file = "f:\\Users\\d-nnis\\reapWP_cookie.txt";
my $cookie_booklooker = "f:\\Users\\d-nnis\\cookie_booklooker.txt";
my $manuell_cookie = "f:\\Users\\d-nnis\\bookl_cookie_manuell.txt";
my $username = $config{uname};
my $password = $config{pwd};

my $browser = WWW::Mechanize->new();
my $tp = HTML::TokeParser->new(doc => \$browser->content);

my $bookl=Booklooker->new;
$bookl->login;
$bookl->merkzettel;
# liste: n verkäufer pro buch
$bookl->{verk_n} = 3;
my %verk_liste = ();
foreach my $titel (keys %{$bookl->{buecher}}) {
	# rufe suche auf
	$bookl->suche_titel($titel);
#	if ($bookl->{treffer} == 0) {
#		# vermerk dafür?
#		next;
#	}
	# pro buch die ersten n ( $bookl->{verk_n} ) Verkäufer heraus suchen
	$bookl->sammel_verk($titel);
	#-> $bookl->{verk_liste};
}
#
foreach my $verk (keys %{$bookl->{verk_liste}}) {
	$bookl->suche_verk_buecher($verk);
}

exit 2;

# lade Inhalt in den TokeParser
sub tp_content {
	$tp = HTML::TokeParser->new(doc => \$browser->content);
}
sub getstate {
	File::writefile($output_file, $browser->content);
	my @args = ("f:\\Program Files (x86)\\K-Meleon\\k-meleon.exe",$output_file);
	system(@args); 
}
sub convert_char {
	my $string = shift;
	my $wert;
	#my @arr = split//, $string;
	#$string =~ s/[ä,ö,ü,Ä,Ö,Ü,ß]/('&auml;', '&ouml;', '&uuml;', '&Auml;', '&Ouml;', '&Uuml;', '&szlig;')/;
#	$string =~ s/ä/&auml;/;
#	$string =~ s/ö/&ouml;/;
#	$string =~ s/ü/&uuml;/;
#	$string =~ s/Ä/&Auml;/;
#	$string =~ s/Ö/&Ouml;/;
#	$string =~ s/Ü/&Uuml;/;
#	$string =~ s/ß/&szlig;/;
#	$string=~s/Ä/Ã\204/;
#	$string=~s/Ö/Ã\226/;
#	$string=~s/Ü/Ã\234/;
#	$string=~s/ß/Ã\237/;
#	$string=~s/ö/Ã¶/;
#	$string=~s/ü/Ã¼/;
#	$string=~s/ä/Ã¤/;

	#$wert=~s/Ã\204/Ä/;
	#$wert=~s/Ã\226/Ö/;
	#$wert=~s/Ã\234/Ü/;
	#$wert=~s/Ã\237/ß/;
	#$wert=~s/Ã¶/ö/;
	#$wert=~s/Ã¼/ü/;
	#$wert=~s/Ã¤/ä/;
	$string =~ s/ü/%FC/g;
	$string =~ s/ö/%F6/g;
	$string =~ s/ä/%E4/g;
	$string =~ s/Ü/%DC/g;
	$string =~ s/Ö/%D6/g;
	$string =~ s/Ä/%C4/g;
	$string =~ s/ß/%DF/g;
	$string =~ s/\s/+/g;
	#$string = encode('iso-8859-1', $string);
	# latin1 rüberkommen
	#$string = uri_escape_utf8($string);
	return $string;
}

###################
package Booklooker;
###################
sub new {
	my $class = shift;
	my $self = {};
	bless ($self, $class);
	# mech nur package-intern sichtbar
	#$self->{mech} = WWW::Mechanize->new();
	return $self;
}

sub login {
	my $self = shift;
	#my $cookie_jar = HTTP::Cookies->new();
	my $cookie_jar = HTTP::Cookies->new(file => "$cookie_file", autosave => 1);
	$cookie_jar->clear("web6.codeprobe.de");
	#$cookie_jar->load($manuell_cookie);
	$cookie_jar->load($cookie_booklooker);
	$browser->cookie_jar($cookie_jar);
	$browser->get($url);
	if ($self->is_logged_in) {
		print "Already logged in booklooker.de\n";
	} else {
		$browser->get($url_login);
		$browser->form_name('f');
		$browser->field(loginName=>$username);
		$browser->field(loginPass=>$password);
		$browser->tick("longSession", "on");
		main::getstate;
		$browser->click();
		$cookie_jar->save($cookie_booklooker);
		#$cookie_jar = HTTP::Cookies->new(file => "$cookie_file", autosave => 1);
		print "Now logged in booklooker.de\n" if $self->is_logged_in;
	}
	#my $page_content = $browser->content();
}

sub is_logged_in {
	my $self = shift;
	main::tp_content;
	main::getstate;
	my $in = 0;
	while (my $token=$tp->get_tag("div")) {
		$in = 1 if ($token->[1]{id} eq "header_logout");	
	}
	if ($in == 1) {
		print "Logged in!\n";
		return 1;
	} else {
		print "Not logged in!\n";
		return 0;
	}
}

## suche Liste mit Tupeln heraus: artikeltitel, autor, verkaeufer etc.
sub merkzettel {
	my $self = shift;
	$browser->follow_link(text=>'Merkzettel');
	#my $tp = HTML::TokeParser->new(file=>"f:\\Users\\d-nnis\\BL_Merkzettel.html"|| die "Can't open: $!");
	#my $tp = HTML::TokeParser->new(doc => \$browser->content);
	my $content = $browser->content;
	#$tp = HTML::TokeParser->new(doc => \$browser->content);
	main::getstate;
	%{$self->{buecher}} = ();
	$self->tokeparse_titel;
#	while (my $token = $tp->get_tag("span")) {
#		# ein Buch
#		next unless $token->[1]{class} eq 'artikeltitel'; 
#		my $text_titel = $tp->get_trimmed_text("/span");
#		${$self->{buecher}}{$text_titel}{autor} = $tp->get_trimmed_text("br"); # Autor 
#		${$self->{buecher}}{$text_titel}{verlag} = $tp->get_trimmed_text("br/");
#		${$self->{buecher}}{$text_titel}{zustand} = $tp->get_trimmed_text("/td");
#		${$self->{buecher}}{$text_titel}{preis} = $tp->get_trimmed_text("br/");
#		${$self->{buecher}}{$text_titel}{porto} = $tp->get_trimmed_text("br");
#	}
}

sub tokeparse_titel {
	my $self = shift;
	my %buecher = ();
	main::tp_content;
	while (my $token = $tp->get_tag("span")) {
		# ein Buch
		next unless $token->[1]{class} eq 'artikeltitel'; 
		my $text_titel = $tp->get_trimmed_text("/span");
		#${$self->{buecher}}{$text_titel}{autor} = $tp->get_trimmed_text("br"); # Autor 
		#${$self->{buecher}}{$text_titel}{verlag} = $tp->get_trimmed_text("br/");
		#${$self->{buecher}}{$text_titel}{zustand} = $tp->get_trimmed_text("/td");
		#${$self->{buecher}}{$text_titel}{preis} = $tp->get_trimmed_text("br/");
		#${$self->{buecher}}{$text_titel}{porto} = $tp->get_trimmed_text("br");
		$buecher{$text_titel}{autor} = $tp->get_trimmed_text("br"); # Autor 
		$buecher{$text_titel}{verlag} = $tp->get_trimmed_text("br/");
		$buecher{$text_titel}{zustand} = $tp->get_trimmed_text("/td");
		$buecher{$text_titel}{preis} = $tp->get_trimmed_text("br/");
		$buecher{$text_titel}{porto} = $tp->get_trimmed_text("br");
		%{$self->{buecher}} = (%{$self->{buecher}}, %buecher);
		#return %buecher;
		print "";
	}
}

sub suche_titel {
	my $self = shift;
	my $titel = shift;
	$self->{treffer} = 0;
	#$browser->get("https://secure.booklooker.de/app/search.php");
	# https://secure.booklooker.de/app/result.php?token=0059526311&mediaType=0&sortOrder=&js_state=on&autocomplete=off&message=&autor=autor%FC%F6%E4%DC%D6%C4%DFautor&titel=titel%FC%F6%E4%DC%D6%C4%DFtitel&infotext=&verlag=&isbn=&year_from=&year_to=&sprache=&einbandCategory=&price_min=&price_max=&searchUserTyp=0&land=&datefrom=&oldBooks=on&newBooks=on&x=0&y=0
	my $url_prefix = 'https://secure.booklooker.de/app/result.php?token=0059526311&mediaType=0&sortOrder=&js_state=on&autocomplete=off&message=&autor=';
	my $url_autor = main::convert_char(${$self->{buecher}}{$titel}{autor});
	my $url_infix = '&titel=';
	my $url_titel = main::convert_char($titel);
	my $url_postfix = '&infotext=&verlag=&isbn=&year_from=&year_to=&sprache=&einbandCategory=&price_min=&price_max=&searchUserTyp=0&land=&datefrom=&oldBooks=on&newBooks=on&x=0&y=0';
	my $url = $url_prefix.$url_autor.$url_infix.$url_titel.$url_postfix;
	$browser->get($url);
	
	#$browser->form_name('eingabe');;
	#$browser->field(titel=>main::convert_char($titel));
	#$browser->field(autor=>main::convert_char($autor));
	#$browser->click();
	# Treffer?
	if ( $browser->content() =~ /<h1 class="headline_buch">Keine Treffer im Bereich/ ) {	# kein Treffer für den Titel
		main::getstate;
		return;
	}
	# Sortierung nach Preis
	main::getstate();
	if ($browser->find_link('Preis')) {
		$browser->follow_link(text=>'Preis');
	}
	# Anzeige auf 50 Titel vergrößern
	if ($browser->find_link(text=>'50')) {
		$browser->follow_link(text=>'50');
		main::getstate();		
		
	}
	main::tp_content;
	#while (my $token = ($tp->get_tag("td"))->[1]{class} ) {
	while (my $token = $tp->get_tag("td")) {
		my $att = $token->[1]{class};
		next unless $att eq 'resultlist_count';
		my $text = $tp->get_trimmed_text("/td");
		$text =~ /(\d+)\sTreffer/;
		${$self->{buecher}}{$titel}{treffer} = $1;
		last;
	}
	print "";
}

sub sammel_verk {
	my $self = shift;
	my $titel = shift;
	my %verk_liste;
	# leere liste drauf gepusht
	my $verk_gesammelt_0 = 0;	# Ergebnisse, Ebene 0
	my $verk_gesammelt_1 = 0;	# Ergebnisse, Ebene 1
	main::tp_content;
	main::getstate;
	my $offerers = 0;
	while (($verk_gesammelt_0 + $verk_gesammelt_1) < $self->{verk_n}) {
		# folge dem Angebot
		# links exists!?	
		my $link_found = $browser->find_link(text_regex=> qr/$titel/i, n=>$verk_gesammelt_0+1);
		# ersetzen mit:
		my $link = WWW::Mechanize::Link->new(text_regex=> qr/$titel/i, n=>$verk_gesammelt_0+1);
		my $url = $link_found;
		unless ($link_found) {
			main::getstate;
			last;
		}
		# hinweis auf gefundene bücher i.e. follow_link-fault?
		# follow_link(url=>'http')
		$browser->follow_link(text_regex=> qr/$titel/i, n=>$verk_gesammelt_0+1);
		# ersetzen mit: $browser->follow_link($found_link); oder $browser->follow_link($link); 
		main::tp_content;
		main::getstate;
		## Verkäufer oder Verkäuferliste?
		while (my $token2 = $tp->get_tag("h2")) {
			$offerers = 1 if $token2->[1]{class} eq 'offerers';
		}
		if ($offerers) {
			## b) Liste
			## Verkäufernamen
			## zähle Verkäufer
			#$browser->find_all_links(tag=>"a", attrs=>{class});
			my $parser = MyParser->new();
			my $sellerinfos = $parser->parse();
			##
			while (my $token3 = $tp->get_tag("td")) {
				next unless $token3->[1]{class} eq "sellerinfo";
				my $text = $tp->get_trimmed_text("/td");
				$text =~ /von\s(.+)/;
				$verk_liste{$1}=1;
				#$self->{verk_liste}{$text_verk}=$uID;
				# keine uID hier! erst im nächsten Schritt:
				
				$self->{verk_liste}{$1}=1;
				$verk_gesammelt_1++;
				last if ($self->{verk_n}) => $verk_gesammelt_0 + $verk_gesammelt_1;
				# <td class="sellerinfo">
				# =~ /von <a href.+\>(.+)<\\a>/
				# </td>
				# Fall: Ende der Verkäuferliste
				# mech->back!?
				# $offerers = 0 wann?
			}
		} else {
			## a) ein Artikel
			## Verkäufernamen
			main::tp_content;
			my $text_verk;
			my $uID;
			while (my $token3 = $tp->get_tag("a")) {
				my $attrdesc = $token3->[1]{href};
				next unless ($attrdesc =~ /profileuID=(\d+)/);
				$uID=$1;
				$text_verk = $tp->get_trimmed_text("/a");
				next if $text_verk =~ /Benutzer-Profil/;
				last;
			}
			$self->{verk_liste}{$text_verk}=$uID;
			#{Steinberger Hof}=231232
			print "match:--$text_verk--\n"; 
			$verk_gesammelt_0++;
			$browser->back();
			main::getstate;
			print "";
		}
	}
	#return %verk_liste;
}

sub suche_verk_buecher {
	my $self = shift;
	my $verk = shift;
	my $uID = ${$self->{verk_liste}}{$verk};
	$browser->get("https://secure.booklooker.de/app/search.php");
	foreach my $titel (keys %{$self->{buecher}}) {
		my @url;
		$url[0] = 'https://secure.booklooker.de/app/search_user.php?searchUsername=';
		$url[1] = main::convert_char($verk);
		$url[2] = '&x=0&y=0';
		my $url = join '',@url; 
		$browser->get($url);
		#https://secure.booklooker.de/app/search_user.php?searchUsername=
		#Steinberger+Hof
		#&x=0&y=0
		#$browser->form_name("eingabe");
		#$browser->field(searchUsername=>main::convert_char($verk));
		#$browser->click();
		main::getstate;
		# Profil von Verkäufer
		$browser->follow_link(text_regex=>qr/\d+ Bücher/);
		main::getstate;
		# Suchformular mit Verkäufer
		my @url2;
		push @url2, 'https://secure.booklooker.de/app/result.php?sortOrder=preis_euro&setMediaType=0&autor=';
		push @url2, main::convert_char(${$self->{buecher}{$titel}}{autor});
		push @url2, '&verlag=&isbn=&sprache=&einbandCategory=&einband=&titel='; 
		push @url2, main::convert_char($titel);
		push @url2, '&infotext=&year_from=&year_to=&sparteID=&sparte1ID=&showAlluID=';
		push @url2, $uID;
		push @url2, '&cheapie=&price_min=&price_max=&datefrom=&searchUserTyp=0&land=&lfdnr=&hasPic=&onlySwiss=&message=&newBooks=on&oldBooks=on&';
		my $url2 = join '', @url2;
		#https://secure.booklooker.de/app/result.php?sortOrder=preis_euro&setMediaType=0&autor=
		#Thomas+Anders
		#&verlag=&isbn=&sprache=&einbandCategory=&einband=&titel=
		#100+Prozent+Anders
		#&infotext=&year_from=&year_to=&sparteID=&sparte1ID=&showAlluID=
		#3253529
		#&cheapie=&price_min=&price_max=&datefrom=&searchUserTyp=0&land=&lfdnr=&hasPic=&onlySwiss=&message=&newBooks=on&oldBooks=on&
		
		#$browser->form_name("eingabe");
		#$browser->field(autor=>main::convert_char(${$self->{buecher}{$titel}}));
		#$browser->field(titel=>main::conver_char($titel));
		main::getstate;
		$browser->click();
		main::getstate;
		# Suchergebnis
		my $treffer = 0;
		while (my $token = $tp->get_tag("span")) {
			next unless $token->[1]{class} eq 'artikeltitel';
			$treffer = 1;
			my $text_titel = $tp->get_trimmed_text("/span");
			# 1 Titel oder mehr	
			# Buchtitel
			# Preis
			# Porto etc.
			# {verk}{titel}
			# {verk}{autor}
			# {verk}{verlag}
			# {verk}{zustand}
			# {verk}{preis}
			# {verk}{porto}
			${$self->{verk_buecher}}{$verk}{titel} = $tp->get_trimmed_text("/span");
			${$self->{verk_buecher}}{$verk}{autor} = $tp->get_trimmed_text("br"); # Autor 
			${$self->{verk_buecher}}{$verk}{verlag} = $tp->get_trimmed_text("br/");
			${$self->{verk_buecher}}{$verk}{zustand} = $tp->get_trimmed_text("/td");
			${$self->{verk_buecher}}{$verk}{preis} = $tp->get_trimmed_text("br/");
			${$self->{verk_buecher}}{$verk}{porto} = $tp->get_trimmed_text("br");
		}
		# if treffer = 0: keine titel
		print "";
	}
}


sub tp_content {
	my $self = shift;
	$self->{tp} = HTML::TokeParser->new(doc => \$browser->content);
}

package MyParser;

# This parser only looks at opening tags
# start: Handler for the event 'start' METHODS -> Events
# tagname: argspec identifier 'tagname' (METHODS -> Argspec)
#sub start { 
#	my ($self, $tagname, $attr, $attrseq, $origtext) = @_;
#	#print @_,"\n";
#	given ($tagname) {
#		when (/a/) {
#			#print "a: Schluessel: ", keys %$attr, "\n";
#		}
#		when (/tr/) {
#			if ($attr->{class} && $attr->{class} eq 'resultlist_productsproduct') {
#				my $tee = $self->text();
#				print "";
#				print "tr: Schluessel: ", keys %$attr, "\n";
#				print "class: ", $attr->{class}, "\n";
#				print "content: ", $attr->{content}, "\n";
#			}
#
#		}			
#	}
#}
#
#sub text {
#	my ($self, $wtf) = @_;
#	print ""; #$wtf;
#}

## new

sub start {
	my $sellerinfos = 0;
	my ($self, $tagname, $attr, $attrseq, $origtext) = @_;
	given ($tagname) {
		when ("td") {
			if ($attr->{class} && $attr->{class} eq 'sellerinfo') {
				my $tee = $self->text();
				print "";
				print "tr: Schluessel: ", keys %$attr, "\n";
				print "class: ", $attr->{class}, "\n";
				print "content: ", $attr->{content}, "\n";
				$sellerinfos++;
			}

		}
	}
	return $sellerinfos;
}

sub text {
	my ($self, $wtf) = @_;
	return $wtf;
}
