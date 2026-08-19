class Snooze < Formula
  desc "Temporarily mute Zabbix hosts and hostgroups"
  homepage "https://github.com/rtulke/snooze"
  url "https://github.com/rtulke/snooze/archive/refs/tags/v2.5.tar.gz"
  sha256 "2d94037a8c3d48a81dac40f656e2425596af578468b07185deb31ce4f44b3236"
  license "GPL-3.0-or-later"
  head "https://github.com/rtulke/snooze.git", branch: "main"

  # snooze is stdlib-only (no pip dependencies) but still needs a real
  # python3 - macOS's own /usr/bin/python3 stub just prompts to install
  # Xcode Command Line Tools rather than running anything, so a brewed
  # Python is required like any other Python-shebang CLI formula.
  depends_on "python@3.13"

  def install
    bin.install "snooze"
    man1.install "packaging/snooze.1"
    bash_completion.install "etc/bash_completion.d/snooze"
    doc.install "README.md", "README_de.md", "REFERENCE.md", "REFERENZ_de.md"
    doc.install "etc/snooze.conf.example" => "snooze.conf.example"
  end

  def caveats
    <<~EOS
      snooze needs a Zabbix API token to do anything beyond --help/--version:
        cp #{doc}/snooze.conf.example ~/.snooze.conf
        $EDITOR ~/.snooze.conf   # set url + token

      Or skip the file entirely and set SNOOZE_TOKEN (+ SNOOZE_URL) in the
      environment instead.

      See `man snooze` or `snooze --help` for all commands, and the full
      documentation at https://github.com/rtulke/snooze#readme (German at
      https://github.com/rtulke/snooze/blob/main/README_de.md).

      Note: homebrew-core ships an unrelated tool of the same name (a cron
      replacement). Core wins over a tap for a bare formula name, so always
      install and upgrade this one as rtulke/snooze/snooze. Both provide a
      `snooze` binary and cannot be linked at the same time.
    EOS
  end

  test do
    # Loose match on purpose: the formula's derived `version` (from the
    # release tag) and the string snooze itself prints via --version don't
    # have to share an exact format - just confirm the binary runs and
    # identifies itself.
    assert_match "snooze", shell_output("#{bin}/snooze --version")
  end
end
