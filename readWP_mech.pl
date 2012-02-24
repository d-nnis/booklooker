use strict;
use warnings;
use Essent_BL;
use WWW::Mechanize;
use HTTP::Cookies;
use feature qw/switch/;
use HTML::PullParser;
use HTML::TokeParser;
#use HTML::Parser;
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
my $export_file = "f:\\Users\\d-nnis\\reapWP_exportfile.csv";
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

foreach my $verk (keys %{$bookl->{verk_liste}}) {
	$bookl->suche_verk_buecher($verk);
}
# $self->{verk_liste}{$verk}{uID};
# $self->{verk_liste}{$verk}{anzahl_titel} = $anzahl_titel;
# $self->{verk_liste}{$verk}{titel} = @titel;
# $self->{verk_liste}{$verk}{summe_preis} = $summe_preis;


$bookl->uebersicht_verk_liste;
$bookl->export_csv($export_file);

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
	# $string =~ s/ä/&auml;/;
	# $wert=~s/Ã\204/Ä/;
	$string =~ s/ü/%FC/g;
	$string =~ s/ö/%F6/g;
	$string =~ s/ä/%E4/g;
	$string =~ s/Ü/%DC/g;
	$string =~ s/Ö/%D6/g;
	$string =~ s/Ä/%C4/g;
	$string =~ s/ß/%DF/g;
	$string =~ s/\s/+/g;
	return $string;
}

sub field_iso {
	my $string = shift;
	#$string = convert_char($string);
	#$string = encode('iso-8859-1', $string);
	#$string = uri_escape_utf8($string);
	$string = uri_escape_utf8(encode('iso-8859-1', $string));
	return $string;
}

sub parse_betrag {
	my $betrag_roh = shift;
	$betrag_roh =~ /(\d+.\d+)/;
	my $betrag = $1;
	$betrag =~ s/\,/\./;
	return $betrag;
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
		$browser->click();
		$cookie_jar->save($cookie_booklooker);
		print "Now logged in booklooker.de\n" if $self->is_logged_in;
	}
}

sub is_logged_in {
	my $self = shift;
	main::tp_content;
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
	my $content = $browser->content;
	%{$self->{buecher}} = ();
	$self->tokeparse_titel;
}

sub tokeparse_titel {
	my $self = shift;
	my %buecher = ();
	main::tp_content;
	while (my $token = $tp->get_tag("span")) {
		# ein Buch
		next unless $token->[1]{class} eq 'artikeltitel'; 
		my $text_titel = $tp->get_trimmed_text("/span");
		$buecher{$text_titel}{autor} = $tp->get_trimmed_text("br"); # Autor 
		#$buecher{$text_titel}{verlag} = $tp->get_trimmed_text("br/");
		#$buecher{$text_titel}{zustand} = $tp->get_trimmed_text("/td");
		#$buecher{$text_titel}{preis} = main::parse_betrag($tp->get_trimmed_text("br/"));
		#$buecher{$text_titel}{porto} = main::parse_betrag($tp->get_trimmed_text("br"));
		%{$self->{buecher}} = (%{$self->{buecher}}, %buecher);
	}
}

sub suche_titel {
	my $self = shift;
	my $titel = shift;
	$self->{treffer} = 0;
	
	## Suche mit field - funzt nicht
#	$browser->get("https://secure.booklooker.de/app/search.php");
#	$browser->form_name('eingabe');
#	#$browser->field(titel=>$titel);
#	$browser->field(titel=>main::field_iso($titel));
#	my $autor = ${$self->{buecher}}{$titel}{autor};
#	$browser->field(autor=>main::field_iso($autor));
#	$browser->click();
#	main::getstate;
	
	
	# https://secure.booklooker.de/app/result.php?token=0059526311&mediaType=0&sortOrder=&js_state=on&autocomplete=off&message=&autor=autor%FC%F6%E4%DC%D6%C4%DFautor&titel=titel%FC%F6%E4%DC%D6%C4%DFtitel&infotext=&verlag=&isbn=&year_from=&year_to=&sprache=&einbandCategory=&price_min=&price_max=&searchUserTyp=0&land=&datefrom=&oldBooks=on&newBooks=on&x=0&y=0
	my $url_prefix = 'https://secure.booklooker.de/app/result.php?token=0059526311&mediaType=0&sortOrder=&js_state=on&autocomplete=off&message=&autor=';
	my $url_autor = main::convert_char(${$self->{buecher}}{$titel}{autor});
	my $url_infix = '&titel=';
	my $url_titel = main::convert_char($titel);
	my $url_postfix = '&infotext=&verlag=&isbn=&year_from=&year_to=&sprache=&einbandCategory=&price_min=&price_max=&searchUserTyp=0&land=&datefrom=&oldBooks=on&newBooks=on&x=0&y=0';
	my $url = $url_prefix.$url_autor.$url_infix.$url_titel.$url_postfix;
	$browser->get($url);
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
	while (my $token = $tp->get_tag("td")) {
		my $att = $token->[1]{class};
		next unless $att eq 'resultlist_count';
		my $text = $tp->get_trimmed_text("/td");
		$text =~ /(\d+)\sTreffer/;
		${$self->{buecher}}{$titel}{treffer} = $1;
		last;
	}
}

sub sammel_verk {
	my $self = shift;
	my $titel = shift;
	my %verk_liste;
	my $verk_gesammelt_0 = 0;	# Ergebnisse, Ebene 0
	my $verk_gesammelt_1 = 0;	# Ergebnisse, Ebene 1
	main::tp_content;
	main::getstate;
	my $offerers = 0;
	while (($verk_gesammelt_0 + $verk_gesammelt_1) < $self->{verk_n}) {
		# folge dem Angebot
		# link exists!?	
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
			main::getstate;
			my $parser = MyParser->new();
			my $parse_object = $parser->parse($browser->content);
			my $seller_number = ${$parse_object}{seller_number};
## example	
#<td class="sellerinfo">
#									<a href="/app/detail.php?id=A0168TH40dlTd00ZZl&setMediaType=0"><img style="margin: 3px; border: 0;" align="left" src="https://images.booklooker.de/isbn_thumb/9783440122648/cover.jpg"></a>
#													von <a href="/app/detail.php?id=A0168TH40dlTd00ZZl&setMediaType=0">Bücherinsel</a><br/>
#
			# alle Verkäufer via td class="sellerinfo" sammeln
			main::tp_content;
			my @verk_liste_offerers;
			while (my $token3 = $tp->get_tag("td")) {
				my $attrdesc = $token3->[1]{class};
				next unless $attrdesc eq "sellerinfo";
				my $text_verk_offerers = $tp->get_trimmed_text("br/");
				$text_verk_offerers =~ /von\s([\w\s]+)/;
				push @verk_liste_offerers, $1;
				$verk_gesammelt_1++;
				last if $verk_gesammelt_1 >= $seller_number;
				last if ($self->{verk_n}) >= $verk_gesammelt_0 + $verk_gesammelt_1;
			}
			# für jeden Verkäufer die uID von Profile-Seite holen
			foreach my $verk (@verk_liste_offerers) {
				$browser->follow_link(text=>"$verk");
				my ($text_verk, $uID) = $self->get_userprofile();
				#$self->{verk_liste}{$text_verk}=$uID;
				$self->{verk_liste}{$text_verk}{uID}=$uID;					
				$browser->back;
			}
		} else {
			## a) ein Artikel
			## Verkäufernamen
			my ($text_verk, $uID) = $self->get_userprofile();
			$self->{verk_liste}{$text_verk}{uID}=$uID;
			#{Steinberger Hof}=231232
			$verk_gesammelt_0++;
			$browser->back();
		}
	}
	#return %verk_liste;
}

sub get_userprofile {
	my $self = shift;
	main::tp_content;
	my $text_verk;
	my $uID;
	while (my $token = $tp->get_tag("a")) {
		my $attrdesc = $token->[1]{href};
		next unless ($attrdesc =~ /profileuID=(\d+)/);
		$uID=$1;
		$text_verk = $tp->get_trimmed_text("/a");
		next if $text_verk =~ /Benutzer-Profil/;
		last;
	}
	return ($text_verk, $uID);
}

# Suche einen Verkäufer auf gesamte Bücherliste ab
sub suche_verk_buecher {
	my $self = shift;
	my $verk = shift;
	my $uID = ${$self->{verk_liste}}{$verk}{uID};
	$browser->get("https://secure.booklooker.de/app/search.php");
	foreach my $titel (keys %{$self->{buecher}}) {
#		my @url;
#		$url[0] = 'https://secure.booklooker.de/app/search_user.php?searchUsername=';
#		$url[1] = main::convert_char($verk);
#		$url[2] = '&x=0&y=0';
#		my $url = join '',@url; 
#		$browser->get($url);
#		#https://secure.booklooker.de/app/search_user.php?searchUsername=
#		#Steinberger+Hof
#		#&x=0&y=0
#		#$browser->form_name("eingabe");
#		#$browser->field(searchUsername=>main::convert_char($verk));
#		#$browser->click();
#		main::getstate;
#		# Profil von Verkäufer
#		$browser->follow_link(text_regex=>qr/\d+ Bücher/);
#		main::getstate;
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
		#$browser->click();
		$browser->get($url2);
		main::getstate;
		# Suchergebnis
		my $treffer = 0;
		while (my $token = $tp->get_tag("span")) {
			next unless $token->[1]{class} eq 'artikeltitel';
			$treffer = 1;
			my $text_titel = $tp->get_trimmed_text("/span");
			${$self->{verk_buecher}}{$verk}{titel} = $tp->get_trimmed_text("/span");
			${$self->{verk_buecher}}{$verk}{titel}{autor} = $tp->get_trimmed_text("br"); # Autor
			# ${$self->{verk_buecher}}{$verk}{autor} = $tp->get_trimmed_text("br"); # Autor
			${$self->{verk_buecher}}{$verk}{titel}{verlag} = $tp->get_trimmed_text("br/");
			${$self->{verk_buecher}}{$verk}{titel}{zustand} = $tp->get_trimmed_text("/td");
			${$self->{verk_buecher}}{$verk}{titel}{preis} = main::parse_betrag($tp->get_trimmed_text("br/"));
			${$self->{verk_buecher}}{$verk}{titel}{porto} = main::parse_betrag($tp->get_trimmed_text("br"));
		}
		# keine titel
		print "";
	}
}

# verk_liste{verk}->uID
# verk_liste{verk}->#titel
# verk_liste{verk}->@titel
# verk_liste{verk}->summe preis
sub uebersicht_verk_liste {
	my $self = shift;
	my $anzahl_titel;
	my $summe_preis = 0;
	print 4.5 + 2.1, "\n";
	foreach my $verk (keys %{$self->{verk_buecher}}) {
		my @titel = keys %{${$self->{verk_buecher}}{$verk}};
		my $anzahl_titel = scalar @titel;
		foreach (@titel) {
			$summe_preis = $summe_preis + ${$self->{verk_buecher}}{$verk}{$_}{preis};
		}
		# $self->{verk_liste}{$verk}{uID};
		$self->{verk_liste}{$verk}{anzahl_titel} = $anzahl_titel;
		$self->{verk_liste}{$verk}{titel} = @titel;
		$self->{verk_liste}{$verk}{summe_preis} = $summe_preis;
	}
	

	
}

sub export_csv {
	my $self = shift;
	my $export_file = shift;
	my @titel = keys %{$self->{buecher}};
	my @verk = keys %{$self->{verk_liste}};
	# titel: ${$self->{buecher}}{$titel}
	my $line;
	my @matrix;
	foreach my $verk (@verk) {
		# Spalten
		# Verk, Anzahl Titel
		$line = Essent_BL::remove_ws($verk) . "," . ${$self->{verk_liste}}{$verk}{anzahl_titel} . ",";
		# titel1, titel2, titel3 ...		
		foreach my $titel (@titel) {
			# Zeilen
			my @titel_verk;
			@titel_verk = @{$self->{verk_liste}{$verk}{titel}}; 
			if (grep {$titel eq $_} @titel_verk) {	# existiert gesuchter Titel in der Titel-Liste des Verkäufers?
				$line = $line . $titel . ",";
			} else {
				$line = $line . "-,";
			}
		}
		$line = $line . ${$self->{verk_liste}}{$verk}{summe_preis} . "\n";
		push @matrix, $line;
	}
	File::writefile_count($export_file, @matrix);
	#titel,verk,anzhal_titel,summe_preis
	# ,titel1,titel2,...
	#verk, titel1, titel2
}


sub tp_content {
	my $self = shift;
	$self->{tp} = HTML::TokeParser->new(doc => \$browser->content);
}

package MyParser;
use base qw(HTML::Parser);
#use LWP::Simple ();

## new

sub start {
	my ($self, $tagname, $attr, $attrseq, $origtext) = @_;
	given ($tagname) {
		when ("td") {
			if ($attr->{class} eq "sellerinfo") {
				#my $tee = $self->text();
				#$self->{collect_text} = 1;
#				print "";
#				print "tr: Schluessel: ", keys %$attr, "\n";
#				print "class: ", $attr->{class}, "\n";
#				print "content: ", $attr->{content}, "\n";
#				print "origtext: $origtext\n";
#				print "Text: \n";
#				foreach my $text (@{$self->{text}}) {
#					print $text,",";
#				}
#				print "-\n";
				$self->{seller_number}++;
			}
		}
	}
	return $self->{seller_number};
}

sub end {
#	my ($self, $tag, $origtext) = @_;
#	given ($tag) {
#		when ("br") {
#			print "origtext $origtext\n";
#			$self->{collect_text} = 0;
#		}
#	}
}

sub text {
#	my $self = shift;
#	if ($self->{collect_text}) {
#		push @{$self->{text}}, @_;
#	}	
}
