module Silverpop

  class Transact < Silverpop::Core

    API_POST_URL  = 'https://transact3.silverpop.com/XTMail'
    FTP_POST_URL  = 'transfer3.silverpop.com'
    USERNAME      = 'username'
    PASSWORD      = 'password'

    TMP_WORK_PATH = "#{RAILS_ROOT}/tmp/"

    def initialize(campaign_id, recipients=[], options={})
      super API_POST_URL
      @query_doc, @response_doc = nil, nil
      xml_template(campaign_id, recipients, options)
    end

    def query_xml
      return '' if @query_doc.nil?
      @query_doc.to_s
    end

    def response_xml
      return '' if @response_doc.nil?
      @response_doc.to_s
    end

    def query
      @response_doc = Hpricot::XML( super(@query_doc.to_s) )
      log_error unless success?
    end

    def submit_batch(batch_file_path)
      Net::FTP.open(FTP_POST_URL, USERNAME, PASSWORD) do |ftp|
        ftp.passive = true  # IMPORTANT! SILVERPOP NEEDS THIS OR IT ACTS WEIRD.
        ftp.chdir('transact')
        ftp.chdir('inbound')
        ftp.puttextfile(batch_file_path)
        ftp.close
      end
    end

    def save_xml(file_path)
      File.open(file_path, 'w') do |f|  
        f.puts query_xml
        f.close
      end

      file_path
    end

    def success?
      @response_doc.at('STATUS').innerHTML.to_i == 0
    end

    def error_message
      return 'Query has not been executed.' if @response_doc.blank?
      return false if success?
      @response_doc.at('ERROR_STRING').innerHTML
    end

    def add_recipient(recipient)
      return if recipient.blank?
      
      r_xml = xml_recipient recipient[:email]
      if recipient[:personalizations].size > 0
        r_xml = add_personalizations r_xml, recipient[:personalizations]
      end

      (@query_doc/:XTMAILING).append r_xml
    end
    
    def add_recipients(recipients)
      return if recipients.blank?

      recipients_xml = ''
      recipients.each do |r|
        r_xml = xml_recipient r[:email]
        if r[:personalizations].size > 0
          r_xml = add_personalizations r_xml, r[:personalizations]
        end
        recipients_xml += r_xml
      end
      
      (@query_doc/:XTMAILING).append recipients_xml
    end

    def add_personalizations(recipient_xml, personalizations)
      r_doc = Hpricot::XML(recipient_xml)
      personalizations.each do |p|
        (r_doc/:RECIPIENT).append xml_recipient_personalization p
      end
      r_doc.to_s
    end

  protected

    def log_error
      logger.debug '*** Silverpop::Transact Error: ' + error_message
    end

    def xml_template(campaign_id, recipients=[], options={})
      o = { :transaction_id       => '',
            :show_all_send_detail => 'true',
            :send_as_batch        => 'false',
            :no_retry_on_failure  => 'false'
          }.merge options

      xml = ( 
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'+"\n"+
        '<XTMAILING>'+"\n"+
          '<CAMPAIGN_ID>%s</CAMPAIGN_ID>'+"\n"+
          '<SHOW_ALL_SEND_DETAIL>%s</SHOW_ALL_SEND_DETAIL>'+"\n"+
          '<SEND_AS_BATCH>%s</SEND_AS_BATCH>'+"\n"+
          '<NO_RETRY_ON_FAILURE>%s</NO_RETRY_ON_FAILURE>'+"\n"+
        '</XTMAILING>'
      ) % [ campaign_id,
            o[:show_all_send_detail],
            o[:send_as_batch],
            o[:no_retry_on_failure] ]
      @query_doc = Hpricot::XML(xml)

      unless o[:transaction_id].blank?
        (@query_doc/:XTMAILING).append(
            '<TRANSACTION_ID>%s</TRANSACTION_ID>' % o[:transaction_id] )
      end
      
      add_recipients recipients
    end

    def xml_recipient(email)
      ( "\n" + '<RECIPIENT>'+
          '<EMAIL>%s</EMAIL>'+
          '<BODY_TYPE>HTML</BODY_TYPE>'+
        '</RECIPIENT>' + "\n"
      ) % email
    end

    def xml_recipient_personalization(personalization)
      ( '<PERSONALIZATION>'+
          '<TAG_NAME>%s</TAG_NAME>'+
          '<VALUE>%s</VALUE>'+
        '</PERSONALIZATION>'
      ) % [ personalization[:tag_name], personalization[:value] ]
    end
    
  end

end