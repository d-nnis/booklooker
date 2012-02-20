use strict;
use warnings;
use WWW::Mechanize;
use HTTP::Cookies;
use feature qw/switch/;
use HTML::PullParser;
use HTML::TokeParser;


package main;

my $url = "http://www.booklooker.de/";
my $output_file = "f:\\Users\\d-nnis\\reapWP_output.html"; 
my $cookie_file = "f:\\Users\\d-nnis\\reapWP_cookie.txt";
my $username = '';
my $password = '';


my $mech = WWW::Mechanize->new();
my $tp = HTML::TokeParser->new(doc => \$mech->content);

# dasdas

my $bookl=Booklooker->new;
$bookl->login;
$bookl->merkzettel;
# -> %{$bookl->{buecher}}
#$bookl->lade_suche;
# liste: n verkäufer pro buch
$bookl->{verk_n} = 3;
foreach my $titel (keys %{$bookl->{buecher}}) {
	# rufe suche auf
	$bookl->suche_titel();
	if ($bookl->{treffer} == 0) {
		# vermerk dafür?
		next;
	}
	
	# pro buech die ersten n ( $bookl->{verk_n} ) Verkäufer heraus suchen
	$bookl->sammel_verk;
}
exit 2;


# lade Inhalt in den TokeParser
sub tp_content {
	$tp = HTML::TokeParser->new(doc => \$mech->content);
}
sub getstate {
	writefile($output_file, $mech->content);
}
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

package Booklooker;

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
	$mech->cookie_jar(HTTP::Cookies->new(file => "$cookie_file", autosave => 1));
	$mech->get($url);
	$mech->form_name('f');
	$mech->field(loginName=>$username);
	$mech->field(loginPass=>$password);
	$mech->click();
	my $page_content = $mech->content();
	$mech->follow_link(text=>'Merkzettel');
}

## suche Liste mit Tupeln heraus: artikeltitel, autor, verkaeufer etc.
sub merkzettel {
	my $self = shift;
	#my $tp = HTML::TokeParser->new(file=>"f:\\Users\\d-nnis\\BL_Merkzettel.html"|| die "Can't open: $!");
	#my $tp = HTML::TokeParser->new(doc => \$mech->content);
	my $content = $mech->content;
	#$tp = HTML::TokeParser->new(doc => \$mech->content);
	main::tp_content;
	main::getstate;
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
	while (my $token = $tp->get_tag("span")) {
		# ein Buch
		next unless $token->[1]{class} eq 'artikeltitel'; 
		my $text_titel = $tp->get_trimmed_text("/span");
		${$self->{buecher}}{$text_titel}{autor} = $tp->get_trimmed_text("br"); # Autor 
		${$self->{buecher}}{$text_titel}{verlag} = $tp->get_trimmed_text("br/");
		${$self->{buecher}}{$text_titel}{zustand} = $tp->get_trimmed_text("/td");
		${$self->{buecher}}{$text_titel}{preis} = $tp->get_trimmed_text("br/");
		${$self->{buecher}}{$text_titel}{porto} = $tp->get_trimmed_text("br");
	}
}

sub suche_titel {
	my $self = shift;
	$self->{treffer} = 0;
	foreach my $titel (keys %{$self->{buecher}} ) {
		$mech->get("https://secure.booklooker.de/app/search.php");
		$mech->form_name('eingabe');
		$mech->field(titel=>$titel);
		my $autor = ${$self->{buecher}}{$titel}{autor};
		$mech->field(autor=>$autor);
		$mech->click();
		# Treffer?
		if ( $mech->content() =~ /<h1 class="headline_buch">Keine Treffer im Bereich/ ) {	# kein Treffer für den Titel
			return;
		}
		# Sortierung nach Preis
		main::getstate();
		if ($mech->find_link('Preis')) {
			$mech->follow_link(text=>'Preis');
			main::getstate();
		}
		# Anzeige auf 50 Titel vergrößern
		if ($mech->find_link(text=>'50')) {
			$mech->follow_link(text=>'50');
			main::getstate();		
		}
		print "";
		main::tp_content;
		#while (my $token = ($tp->get_tag("td"))->[1]{class} ) {
		while (my $token = $tp->get_tag("td")) {
			my $att = $token->[1]{class};
			next unless $att eq 'resultlist_count';
			my $text = $tp->get_trimmed_text("/td");
			$text =~ /(\d+)\sTreffer/;
			$self->{treffer} = $1;
			print "";
		}
		return $self->{treffer};
	}
}

sub sammel_verk {
	my $self = shift;
	my $verk_found = 0;

	while ($verk_found < $self->{verk_n}) {
		main::tp_content;
		#$self->tokeparse_titel();
		my $hit_list=0;
		while (my $token = $tp->get_tag("span")) {
			next unless $token->[1]{class} eq 'artikeltitel';
			my $link_name = $tp->get_trimmed_text("/span");
			$hit_list++;
			# folge dem Angebot
			$mech->follow_link(text=>$link_name, n=>$hit_list);
			main::tp_content;
			while (my $token2 = $tp->get_tag("h2")) {
				$token2->[1]{class} eq 'offerers'
			}
			if () {
				
			} else {
				
			}
			$mech->content =~ /nlichen Angebot von (\w+)<\/a>/;
			push @{$self->{verk}}, $1;
			$mech->back();
			main::getstate;
			print "";
		}
		# folge dem Angebot
		# entscheide:
		## a) ein Artikel?
		## Verkäufernamen
		## b) Liste?
		## Verkäufernamen
	}
	for (my $i = 0; $i <=3; $i++) {
		$mech->follow_link(text=>'$titel', n=>$i);	# -> Angebot

		
		$tp = HTML::TokeParser->new(doc => \$mech->content);
		my $tee = ($tp->get_tag("h2"))->[1]{class};
		if ( ($tp->get_tag("h2"))->[1]{class} eq 'offerers') {	# neue Liste
			# sortieren nach 

		} else {	# einzelner Verkäufer
			# -> Verkaeufer-Profil
			$mech->follow_link(text=>'>> Benutzer-Profil (Impressum) anzeigen');
			# -> alle Buecher, Verkäufer-spezifische Suche
			$mech->follow_link(text=>'Bücher');
			foreach my $titel (keys %{$self->{buecher}}) {
				$mech->form_name('eingabe');
				$mech->field(autor=>${$self->{buecher}}{$titel}{autor} = $tp->get_trimmed_text("br")); # Autor
				#$mech->field(autor=>$autor);
				$mech->field(titel=>$titel);
				$mech->click();
				

				if ( $mech->content() =~ /<h1 class="headline_buch">Keine Treffer im Bereich/ ) {	# kein Treffer bei dem Verkäufer
					
				} else {	# Treffer
					# notiere auf Verkäufer (Hash) Preis, Versand etc.
				}
				
			}
		
		}
		
		# wieder zurück
		
#		while (my $token = $tp->get_tag("span")) {
#			# ein Buch
#			print "Token: ", $token->[1]{class}, "\n";
#			next unless $token->[1]{class} eq 'artikeltitel';
#			$number_buecher++; 
#			my $text_titel = $tp->get_trimmed_text("/span");
#			$buecher{$text_titel}{autor} = $tp->get_trimmed_text("br"); # Autor 
#			my $text_hrsg = $tp->get_trimmed_text("br/");
#			my $text_state = $tp->get_trimmed_text("/td");
#		}
	}
}


sub tp_content {
	my $self = shift;
	$self->{tp} = HTML::TokeParser->new(doc => \$mech->content);
}

exit 1;

my %buecher;
my $number_buecher;


### Suche, Start
foreach my $titel (keys %buecher) {
	$mech->get("https://secure.booklooker.de/app/search.php");
	$mech->form_name('eingabe');
	$mech->field(titel=>$titel);
	my $autor = $buecher{$titel}{autor};
	$mech->field(autor=>$autor);
	$mech->click();
	# Sortierung nach Preis
	getstate();
	$mech->follow_link('Preis');
	getstate();
	if ($mech->find_link(text=>'50')) {
		$mech->follow_link('50');
		getstate();		
	}

	# über die ersten n Angebote nach allen anderen keys %buechern suchen
	# 3 Angebote
	for (my $i = 1; $i <=3; $i++) {
		# -> Angebot
		$mech->follow_link(text=>'$titel', n=>$i);
		$tp = HTML::TokeParser->new(doc => \$mech->content);
		my $tee = ($tp->get_tag("h2"))->[1]{class};
		if ( ($tp->get_tag("h2"))->[1]{class} eq 'offerers') {	# neue Liste
			# sortieren nach 

		} else {	# einzelner Verkäufer
			# -> Verkaeufer-Profil
			$mech->follow_link(text=>'>> Benutzer-Profil (Impressum) anzeigen');
			# -> alle Buecher, Verkäufer-spezifische Suche
			$mech->follow_link(text=>'Bücher');
			foreach my $titel (keys %buecher) {
				$mech->form_name('eingabe');
				$mech->field(autor=>$autor);
				$mech->field(titel=>$titel);
				$mech->click();
				

				if ( $mech->content() =~ /<h1 class="headline_buch">Keine Treffer im Bereich/ ) {	# kein Treffer bei dem Verkäufer
					
				} else {	# Treffer
					# notiere auf Verkäufer (Hash) Preis, Versand etc.
				}
				
			}
		
		}
		
		# wieder zurück
		
		while (my $token = $tp->get_tag("span")) {
			# ein Buch
			print "Token: ", $token->[1]{class}, "\n";
			next unless $token->[1]{class} eq 'artikeltitel';
			$number_buecher++; 
			my $text_titel = $tp->get_trimmed_text("/span");
			$buecher{$text_titel}{autor} = $tp->get_trimmed_text("br"); # Autor 
			my $text_hrsg = $tp->get_trimmed_text("br/");
			my $text_state = $tp->get_trimmed_text("/td");
		}
	}
}


# Liste der Titel
# Suche
# über jeden Verkäufer abfrage der Titel

sub check_verkaeufer {
	
}


#############
sub wikka_login {
	my $url = "http://web6.codeprobe.de/wikka/UserSettings";
	my $appurl = "http://web6.codeprobe.de/wikka/SammLung";
	my $output_file = "f:\\Users\\d-nnis\\reapWP_output.html"; 
	my $cookie_file = "f:\\Users\\d-nnis\\reapWP_cookie.txt";
	
	my $username = 'DennisDoe';
	my $password = '6h3vzWikka';
	
	my $mech = WWW::Mechanize->new();
	$mech->cookie_jar(HTTP::Cookies->new(file => "$cookie_file", autosave => 1));
	$mech->get($url);
	#$mech->form_name('');
	$mech->form_id('form_42b90196b4');
	$mech->field(name=>$username);
	$mech->field(password=>$password);
	writefile($output_file, $mech->content);
	$mech->click();
	my $page_content = $mech->content();
	writefile($output_file, $page_content);
	$mech->get($appurl);
	my $sammlung_content = $mech->content();
	writefile($output_file, $sammlung_content);
};





####### OFF

package MyParser;
use base qw(HTML::Parser);

# This parser only looks at opening tags
# start: Handler for the event 'start' METHODS -> Events
# tagname: argspec identifier 'tagname' (METHODS -> Argspec)
sub start { 
	my ($self, $tagname, $attr, $attrseq, $origtext) = @_;
	#print @_,"\n";
	given ($tagname) {
		when (/a/) {
			#print "a: Schluessel: ", keys %$attr, "\n";
		}
		when (/tr/) {
			if ($attr->{class} && $attr->{class} eq 'resultlist_productsproduct') {
				my $tee = $self->text();
				print "";
				print "tr: Schluessel: ", keys %$attr, "\n";
				print "class: ", $attr->{class}, "\n";
				print "content: ", $attr->{content}, "\n";
			}

		}			
	}
}

sub text {
	my ($self, $wtf) = @_;
	print ""; #$wtf;
}
