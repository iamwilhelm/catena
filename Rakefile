
desc "build gem"
task :build do |task, args|
  cmd = "gem build catena.gemspec"
  IO.popen(cmd) { |io| io.each { |line| puts line } }
end

task :push, [:version] do |task, args|
  raise "version missing" if args[:version].nil?
  cmd = "gem push catena-#{args[:version]}.gem"
  IO.popen(cmd) { |io| io.each { |line| puts line } }
end
