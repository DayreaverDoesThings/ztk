################################################################################
#
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) Jove Labs
#     License: Apache License, Version 2.0
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
################################################################################

require "spec_helper"

describe ZTK::Template do

  subject { ZTK::Template }

  before(:all) do
    $logger = ZTK::Logger.new("/dev/null")
    $stdout = File.open("/dev/null", "w")
    $stderr = File.open("/dev/null", "w")
    $stdin = File.open("/dev/null", "r")
  end

  describe "class" do

    it "should be ZTK::Template" do
      subject.should be ZTK::Template
    end

  end

  describe "behaviour" do

    it "should render the template with the supplied context" do
      template_file = File.expand_path(File.join(File.dirname(__FILE__), "..", "support", "test-template.txt.erb"))
      context = { :test_variable => "Hello World" }
      output = subject.render(template_file, context)
      output.should == "Hello World"
    end

  end

end
