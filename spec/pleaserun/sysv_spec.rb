require "testenv"
require "pleaserun/sysv"

describe PleaseRun::SYSV do
  it "inherits correctly" do
    insist { PleaseRun::SYSV.ancestors }.include?(PleaseRun::Base)
  end

  context "#files" do
    subject do
      runner = PleaseRun::SYSV.new("ubuntu-12.04")
      runner.name = "fancypants"
      next runner
    end

    let(:files) { subject.files.collect { |path, content| path } }

    it "emits a file in /etc/init.d/" do
      insist { files }.include?("/etc/init.d/fancypants")
    end
    it "emits a file in /etc/default/" do
      insist { files }.include?("/etc/default/fancypants")
    end
  end

  context "deployment" do
    partytime = superuser?
    it "cannot be attempted", :if => !partytime do
      pending("we are not the superuser") unless superuser?
    end

    context "as the super user", :if => partytime do
      subject { PleaseRun::SYSV.new("ubuntu-12.04") }

      before do
        subject.name = "example"
        subject.user = "root"
        subject.program = "/bin/sh"
        subject.args = [ "-c", "echo hello world; sleep 5" ]

        subject.files.each do |path, content|
          File.write(path, content)
        end
        subject.install_actions.each do |command|
          system(command)
          raise "Command failed: #{command}" unless $?.success?
        end
      end

      after do
        system_quiet("/etc/init.d/#{subject.name} stop")
        subject.files.each do |path, content|
          File.unlink(path) if File.exist?(path)
        end

        # TODO(sissel): Remove the logs, too.
        #log = "/var/log/example.log"
        #File.unlink(log) if File.exist?(log)
      end

      it "should install" do
        insist { File }.exist?("/etc/init.d/#{subject.name}")
      end

      it "should start" do
        # Status should fail before starting
        system_quiet("/etc/init.d/#{subject.name} status")
        reject { $? }.success?

        system_quiet("/etc/init.d/#{subject.name} start")

        system("sh -x /etc/init.d/#{subject.name} status")
        insist { $? }.success?
      end

      it "should stop" do
        system_quiet("/etc/init.d/#{subject.name} start")
        insist { $? }.success?

        system_quiet("/etc/init.d/#{subject.name} stop")
        insist { $? }.success?

        system_quiet("/etc/init.d/#{subject.name} status")
        reject { $? }.success?
      end
    end
  end # real tests
end
