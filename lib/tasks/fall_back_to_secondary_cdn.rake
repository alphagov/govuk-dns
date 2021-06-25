require_relative 'utilities/secondary_cdn'

task :fall_back_to_secondary_cdn do
    secondary_cdn = SecondaryCDN.new
    secondary_cdn.fall_back!
end
