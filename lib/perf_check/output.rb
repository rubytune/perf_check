class PerfCheck

  def print_diff_results(diff)
    if diff.changed?
      print(" Diff: #{diff.file}".bold.light_red)
    else
      print(" Diff: Output is identical!".bold.light_green)
    end
  end

  def print_brief_results
    test_cases.each do |test|
      print(test.resource.ljust(40) + ': ')

      codes = (test.this_profiles+test.reference_profiles).map(&:response_code).uniq
      print("(HTTP "+codes.join(',')+") ")

      printf('%.1fms', test.this_latency)

      puts && next if test.reference_profiles.empty?

      print(sprintf(' (%+5.1fms)', test.latency_difference).bold)
      print_diff_results(test.response_diff) if options.verify_no_diff
      puts
    end
  end

  def print_results_of_compared_paths
    puts("==== Results ====")

    first_test = test_cases[0]
    second_test = test_cases[1]

    test_latency = first_test.this_latency
    reference_latency = second_test.reference_latency

    test_latency_output = latency_output(test_latency)
    reference_latency_output = latency_output(reference_latency)

    puts("reference path:" + first_test.resource.bold)
    puts("test path:" + second_test.resource.bold)

    latency_difference = test_latency - reference_latency

    change_factor = change_factor(latency_difference, reference_latency, test_latency)
    change_factor_output = sprintf('%.1fx', change_factor)
    percent_change = calculate_percent_change(latency_difference, reference_latency)

    formatted_change, color = formatted_change_and_color(
      change_factor_output,
      percent_change,
      latency_difference
    )

    formatted_change = latency_output(latency_difference) + " (#{formatted_change})"
    print_results(reference_latency_output, test_latency, formatted_change, color)
  end

  def print_full_results
    puts("==== Results ====")
    test_cases.each do |test|
      puts(test.resource.bold)

      if test.reference_profiles.empty?
        printf("your branch: ".rjust(15)+"%.1fms\n", test.this_latency)
        next
      end

      reference_latency_output = latency_output(test.reference_latency)
      test_latency_output = latency_output(test.this_latency)

      latency_difference = test.latency_difference
      reference_latency = test.reference_latency
      test_latency = test.this_latency

      change_factor = change_factor(
        latency_difference,
        reference_latency,
        test_latency
      )

      change_factor_output = sprintf('%.1fx', change_factor)
      percent_change = calculate_percent_change(latency_difference, reference_latency)

      formatted_change, color = formatted_change_and_color(change_factor_output, percent_change, latency_difference)
      formatted_change = latency_output(latency_difference) + " (#{formatted_change})"

      print_results(reference_latency_output, test_latency_output, formatted_change, color)
      print_diff_results(test.response_diff) if options.verify_no_diff
    end
  end

  private

  def latency_output(latency)
    sprintf('%.1fms', latency)
  end

  def change_factor(latency_difference, reference_latency, test_latency)
    if latency_difference < 0
      reference_latency / test_latency
    else
      test_latency / reference_latency
    end
  end

  def print_results(reference_latency, test_latency, formatted_change, color)
    puts("reference: ".rjust(15)  + "#{reference_latency}")
    puts("your branch: ".rjust(15)+ "#{test_latency}")
    puts(("change: ".rjust(15)    + "#{formatted_change}").bold.send(color))
  end

  def formatted_change_and_color(change_factor_output, percent_change, latency_difference)
    if percent_change < 10
      formatted_change = "yours is about the same"
      color = :blue
    elsif latency_difference < 0
      formatted_change = "yours is #{change_factor_output} faster!"
      color = :green
    else
      formatted_change = "yours is #{change_factor_output} slower!!!"
      color = :light_red
    end
    [formatted_change, color]
  end

  def calculate_percent_change(latency_difference, reference_latency)
    100*(latency_difference / reference_latency).abs
  end
end
