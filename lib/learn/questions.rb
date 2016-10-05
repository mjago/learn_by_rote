module ModLearn
  class Questions

    def all
      [
        {
          qu: 'what does GAP stand for?',
          ans: 'Generic Accessory Profile'
        },
        {
          qu: 'GAP defines devices to be one of...',
          ans: 'Central, Peripheral, Observer, Broadcaster'
        },
        {
          qu: 'Who can can initiate a connection to peripheral role devices?',
          ans: 'Central role devices'
        },
        {
          qu: 'Are peripheral devices allowed to initiate connections?',
          ans: 'No'
        },
        {
          qu: 'The peripheral does what with its connection status,',
          ans: 'The peripheral advertises its connection status,'
        },
        {
          qu: 'Who can initiate the bond?',
          ans: 'Once connected, either end of the connection can initiate the bond'
        },
        {
          qu: 'When will security keys be saved?',
          ans: 'Once bonded, all security-related keys will be saved and the security process will be waived when reconnecting. '
        },
        {
          qu: 'Can a bonded peripheral able to connect to other devices whilst bonded?',
          ans: 'The bonded peripheral device can only perform direct advertise; therefore, it is no longer able to connect to devices other than its bonded peer'
        },
      ]
    end
  end
end
