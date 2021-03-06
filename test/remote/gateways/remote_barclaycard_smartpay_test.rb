require 'test_helper'

class RemoteBarclaycardSmartpayTest < Test::Unit::TestCase
  def setup
    @gateway = BarclaycardSmartpayGateway.new(fixtures(:barclaycard_smartpay))

    @amount = 100
    @credit_card = credit_card('4111111111111111', :month => 8, :year => 2018, :verification_value => 737)
    @declined_card = credit_card('4000300011112220', :month => 8, :year => 2018, :verification_value => 737)

    @options = {
      order_id: '1',
      billing_address:       {
              name:     'Jim Smith',
              address1: '100 Street',
              company:  'Widgets Inc',
              city:     'Ottawa',
              state:    'ON',
              zip:      'K1C2N6',
              country:  'CA',
              phone:    '(555)555-5555',
              fax:      '(555)555-6666'},
      email: 'long@bob.com',
      customer: 'Longbob Longsen',
      description: 'Store Purchase'
    }

    @avs_credit_card = credit_card('4400000000000008',
                                    :month => 8,
                                    :year => 2018,
                                    :verification_value => 737)

    @avs_address = @options
    @avs_address.update(billing_address: {
        name:     'Jim Smith',
        street:   'Test AVS result',
        houseNumberOrName: '2',
        city:     'Cupertino',
        state:    'CA',
        zip:      '95014',
        country:  'US'
        })
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Refused', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization, @options)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(nil, '', @options)
    assert_failure response
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization, @options)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(nil, nil, @options)
    assert_failure response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization, @options)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void(nil, @options)
    assert_failure response
  end

  def test_successful_verify
    assert response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal "Authorised", response.message
    assert response.authorization
  end

  def test_unsuccessful_verify
    assert response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal "Refused", response.message
  end

  def test_invalid_login
    gateway = BarclaycardSmartpayGateway.new(
    company: '',
    merchant: '',
    password: ''
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal "Success", response.message
  end

  def test_failed_store
    response = @gateway.store(credit_card('', :month => '', :year => '', :verification_value => ''), @options)
    assert_failure response
    assert_equal "Unprocessable Entity", response.message
  end

  # AVS must be enabled on the gateway's end for the test account used
  def test_avs_result
    response = @gateway.authorize(@amount, @avs_credit_card, @avs_address)
    assert_equal 'N', response.avs_result['code']
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
    assert_scrubbed(@gateway.options[:password], clean_transcript)
  end
end
