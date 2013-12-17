require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new

def gemspec
  @gemspec ||= eval(File.read('kitchen-inspector.gemspec'), binding, 'kitchen-inspector.gemspec')
end

task :default => :build

task :test => :spec

desc 'Builds the documentation using YARD'
task :doc do
  gem_path = Dir.pwd
  command  = "yard doc #{gem_path}/lib -m markdown -o #{gem_path}/doc "
  command += "-r #{gem_path}/README.md --private --protected"

  sh(command)
end

desc "Build gem locally"
task :build do
  gemspec.validate

  system "gem build #{gemspec.name}.gemspec"
  FileUtils.mkdir_p "pkg"
  FileUtils.mv "#{gemspec.name}-#{gemspec.version}.gem", "pkg"
end

desc "Install gem locally"
task :install => :build do
  system "gem install pkg/#{gemspec.name}-#{gemspec.version}.gem"
end

desc "Clean rake artifacts"
task :clean do
  FileUtils.rm_rf ".yardoc"
  FileUtils.rm_rf "doc"
  FileUtils.rm_rf "pkg"
end
