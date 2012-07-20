# Maintainer: ennen <nn at studio25 dot org>
pkgname=ruby-arkweb-3
_gemname=${pkgname#ruby-}
pkgver=0.1.0
pkgrel=1
pkgdesc="A simple document processor suitable for building flat websites."
arch=(any)
url="http://github.com/ennen/arkweb-3"
license=('GPL')
depends=('ruby' 'ruby-maruku' 'ruby-wikicloth' 'ruby-trollop')
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
