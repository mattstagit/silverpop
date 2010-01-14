Gem::Specification.new do |s|
  s.name     = "silverpop"
  s.version  = "1.0.0"
  s.date     = "2010-01-14"
  s.summary  = "Silverpop Engage and Transact API -- Extracted from ShoeDazzle.com"
  s.email    = "george@georgetruong.com"
  s.homepage = "http://github.com/georgetruong/silverpop/tree/master"
  s.description = "Silverpop allows for seamless integration from Ruby with the Engage and Transact API."
  s.authors  = ["George Truong"]

  s.has_rdoc = false
  s.rdoc_options = ["--main", "README"]
  s.extra_rdoc_files = ["README"]

  # run git ls-files to get an updated list
  s.files = %w[
    MIT-LICENSE
    README
    Rakefile
    init.rb
    install.rb
    lib/silverpop.rb
    lib/silverpop/core.rb
    lib/silverpop/engage.rb
    lib/silverpop/transact.rb
    tasks/silverpop_tasks.rake
    test/silverpop_test.rb
    uninstall.rb
  ]
  s.test_files = %w[
  ]
end
