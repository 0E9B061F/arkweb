# This is an example PKGBUILD file. Use this as a start to creating your own,
# and remove these comments. For more information, see 'man PKGBUILD'.
# NOTE: Please fill out the license field for your package! If it is unknown,
# then please put 'unknown'.

# Maintainer: Your Name <youremail@domain.com>
pkgname=ruby-arkweb-3
_gemname=${pkgname#ruby-}
pkgver=0.1.0
pkgrel=1
pkgdesc="A document processor."
arch=(any)
url="http://studio25.org"
license=('GPL')
depends=('ruby' 'rubygems' 'ruby-maruku' 'ruby-wikicloth' 'ruby-trollop')
source=("${_gemname}-${pkgver}.gem")
noextract=("${_gemname}-${pkgver}.gem")
md5sums=('4f83a7208890d230780874c74138651d')

package() {
  cd "$srcdir"
  export HOME=/tmp
  local _gemdir="$(ruby -rubygems -e 'puts Gem.default_dir')"
  gem install --no-user-install --ignore-dependencies -i "${pkgdir}${_gemdir}" ${_gemname}-${pkgver}.gem
}

# vim:set ts=2 sw=2 et:
