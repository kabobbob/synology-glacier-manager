#!/usr/bin/env ruby

require "rubygems"
require "bundler/setup"
require "aws-sdk"
require "pp"
require "yaml"
require "pry"

def choice_input(as_int = false)
  input = gets.chomp

  if input.downcase == 'exit'
    puts ""
    puts "Exiting..."
    exit
  end

  return as_int ? input.to_i : input
end

# load credentials
creds = YAML::load_file "aws_credentials.yml"

# instantiate glacier object
glacier = AWS::Glacier.new(access_key_id: creds['access_key'], secret_access_key: creds['secret_key'])
if glacier.nil?
  puts "Error connecting to AWS::Glacier. Check your connection or credentials."
  exit
end

# get vaults
glacier_vaults = glacier.vaults
if glacier_vaults.nil?
  puts "No vaults found for provided credentials."
  exit
end

vaults = []
glacier_vaults.each do |vault|
  vaults.push(vault)
end

loop do
  # present main options
  puts "Synoglogy Glacier Service"
  puts "type 'exit' at anytime to quit the application"
  puts ""
  puts "[1] - List vaults"

  # get main choice
  print "?: "
  main_choice = choice_input(true)

  case main_choice
  when 1
    loop do
      print "\r\nVaults:\r\n"

      # present vault list
      vaults.each_with_index do |vault, index|
        puts "[#{index + 1}] - vault: #{vault.name} size: #{vault.size_in_bytes} count: #{vault.number_of_archives}"
      end

      # get vault
      print "?: "
      vault_choice = choice_input(true)
      vault = vaults[vault_choice - 1]

      if vault.nil?
        puts "Invalid selection"
      else
        # present vault action list
        loop do
          vault = vaults[vault_choice - 1]
          print "\r\nVault: #{vault.name}\r\n"
          puts "[1] - Initiate inventory retrieval"
          puts "[2] - Initiate archive retrieval"
          puts "[3] - List jobs"
          puts "[0] - Back"
          print "?: "
          action_choice = choice_input(true)

          case action_choice
          when 1
            # submit inventory retrieval request
            print "\r\nInitiating inventory retrieval for vault: #{vault.name}\r\n"

            job_parameters = {
              format: "CSV",
              type: "inventory-retrieval",
              sns_topic: creds['sns_topic']
            }
            ac_response = glacier.client.initiate_job(account_id: vault.account_id, vault_name: vault.name, job_parameters: job_parameters)

            if ac_response.successful?
              puts "Inventory retrieval initiation successful; notificiation to follow."
            else
              puts "Inventory retrieval initiation failure:"
              pp ac_response
            end
          when 2
            # submit archive retrieval request
            print "\r\nInitiating archive retrieval for vault: #{vault.name}\r\n"
            print "ArchiveId: "
            archive_id = choice_input

            job_parameters = {
              type: "archive-retrieval",
              archive_id: archive_id,
              sns_topic: creds['sns_topic']
            }
            ac_response = glacier.client.initiate_job(account_id: vault.account_id, vault_name: vault.name, job_parameters: job_parameters)

            if ac_response.successful?
              puts "Archive retrieval initiation successful; notificiation to follow."
            else
              puts "Archive retrieval initiation failure:"
              pp ac_response
            end
          when 3
            # list jobs for vault
            loop do
              print "\r\nListing jobs for vault: #{vault.name}\r\n"

              # get jobs
              ac_response = glacier.client.list_jobs(account_id: vault.account_id, vault_name: vault.name)

              # create jobs array; present jobs list
              jobs = []
              ac_response.data[:job_list].each do |job|
                jobs.push(job)
                puts "[#{jobs.length}] - action: #{job[:action]} started: #{job[:creation_date]} status: #{job[:status_code]}"
              end
              puts "[0] - Back"

              # get job choice
              printf "?: "
              job_choice = choice_input(true)

              break if job_choice == 0

              job = jobs[job_choice - 1]
              if job.nil?
                puts "Invalid selection"
              else
                # present job actions
                loop do
                  print "\r\nActions for job #{job_choice}\r\n"
                  puts "[1] - Describe job"
                  puts "[2] - Job output" if job[:completed]
                  puts "[0] - Back"

                  # get action choice
                  printf "?: "
                  job_action_choice = choice_input(true)

                  case job_action_choice
                  when 1
                    # describe job
                    jac_response = glacier.client.describe_job(account_id: vault.account_id, vault_name: vault.name, job_id: job[:job_id])
                    pp jac_response.data
                  when 2
                    jac_response = glacier.client.get_job_output(account_id: vault.account_id, vault_name: vault.name, job_id: job[:job_id])

                    # write output to temporary file
                    tempfile = Tempfile.new("#{job[:job_id]}")
                    tempfile.write(jac_response.data[:body])
                    tempfile.close

                    # copy tempfile
                    job_created_at = DateTime.parse(job[:creation_date])
                    output_file_name = "#{job_created_at.strftime('%Y%m%d%H%M')}_#{job[:action]}.csv"
                    FileUtils.cp(tempfile.path, "output_files/#{output_file_name}")
                    tempfile.unlink
                  when 0
                    puts ""
                    break
                  else
                    puts "Invalid selection"
                  end
                end
              end
            end
          when 0
            puts ""
            break
          else
            puts "Invalid selection"
          end
        end
      end
    end
  end
end
