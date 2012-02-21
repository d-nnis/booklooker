use strict;
use warnings;
use Essent_BL;
use WWW::Mechanize;
use HTTP::Cookies;
use feature qw/switch/;
use HTML::PullParser;
use HTML::TokeParser;

my %config = File::readfile("..\\_excl\\login.csv",'config');

##################
package main;
##################

my $url = "http://www.booklooker.de/";
my $output_file = "f:\\Users\\d-nnis\\reapWP_output.html"; 
my $cookie_file = "f:\\Users\\d-nnis\\reapWP_cookie.txt";
my $username = $config{uname};
my $password = $config{pwd};


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
	$bookl->suche_titel($titel);
#	if ($bookl->{treffer} == 0) {
#		# vermerk dafür?
#		next;
#	}
	
	# pro buech die ersten n ( $bookl->{verk_n} ) Verkäufer heraus suchen
	$bookl->sammel_verk($titel);
}
exit 2;


# lade Inhalt in den TokeParser
sub tp_content {
	$tp = HTML::TokeParser->new(doc => \$mech->content);
}
sub getstate {
	File::writefile($output_file, $mech->content);
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
	my $titel = shift;
	$self->{treffer} = 0;
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
	}
	# Anzeige auf 50 Titel vergrößern
	if ($mech->find_link(text=>'50')) {
		$mech->follow_link(text=>'50');
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
	my $verk_found = 0;
	main::tp_content;
	main::getstate;
	my $liste_n = 1;
	my $offerers = 0;
	while ($verk_found < $self->{verk_n}) {
		# folge dem Angebot	
		$mech->follow_link(text_regex=> qr/$titel/i, n=>$liste_n);
		main::tp_content;
		main::getstate;
		while (my $token2 = $tp->get_tag("h2")) {
			$offerers = 1 if $token2->[1]{class} eq 'offerers';
		}
		if ($offerers) {
			## b) Liste
			## Verkäufernamen
			$liste_n = 1;
			while (my $token3 = $tp->get_tag("td")) {
				next unless $token3->[1]{class} eq "sellerinfo";
				my $text = $tp->get_trimmed_text("/td");
				$text =~ /von\s(.+)/;
				push @{$self->{verk}}, $1;
				$verk_found++;
				last if ($self->{verk_n}) => $verk_found;
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
			my $con = $mech->content;
			File::writefile("con.html", $con);
			$con =~ />([\w\s]+)<\/a>\s+| Dieser Artikel wurde bereits/;
			push @{$self->{verk}}, $1;
			$verk_found++;
			$liste_n++;
			$mech->back();
			main::getstate;
			print "";
		}
	}
}


sub tp_content {
	my $self = shift;
	$self->{tp} = HTML::TokeParser->new(doc => \$mech->content);
}

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
