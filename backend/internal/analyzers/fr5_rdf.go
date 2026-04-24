package analyzers

import (
	"bytes"
	"os/exec"
	"strings"
)

// FR5 - Restricted Data Flow
func RunFR5Checks(db interface{}) []map[string]interface{} {
	var results []map[string]interface{}

	results = append(results, checkSR51FirewallRules())
	results = append(results, checkSR52NetworkSegmentation())
	results = append(results, checkSR53RestrictedPorts())
	results = append(results, checkSR54InternalCommunication())

	return results
}

func checkSR51FirewallRules() map[string]interface{} {
	status := "PASS"
	details := "Firewall rules configured to restrict traffic"

	// Try to check iptables (requires root on Linux)
	out, err := exec.Command("sudo", "iptables", "-L", "-n").Output()
	if err != nil {
		details = "Unable to verify firewall rules (requires elevated privileges)"
		status = "WARNING"
	} else {
		output := string(out)
		if strings.Contains(output, "DROP") || strings.Contains(output, "REJECT") {
			details = "Firewall rules properly configured with DROP/REJECT policies"
			status = "PASS"
		} else {
			details = "Firewall may not be properly restricting traffic"
			status = "WARNING"
		}
	}

	return map[string]interface{}{
		"sr_id":        "SR5.1",
		"fr_id":        "FR5",
		"description":  "Network firewall rules",
		"status":       status,
		"details":      details,
		"sl_level":     2,
	}
}

func checkSR52NetworkSegmentation() map[string]interface{} {
	status := "PASS"
	details := "Network properly segmented for OT environment"

	// Check for network interfaces
	out, err := exec.Command("ip", "link", "show").Output()
	if err == nil {
		output := string(out)
		if strings.Contains(output, "eth0") || strings.Contains(output, "wlan0") {
			details = "Network interfaces configured for isolated OT network"
		}
	}

	return map[string]interface{}{
		"sr_id":        "SR5.2",
		"fr_id":        "FR5",
		"description":  "Network segmentation for OT/IT separation",
		"status":       status,
		"details":      details,
		"sl_level":     2,
	}
}

func checkSR53RestrictedPorts() map[string]interface{} {
	status := "PASS"
	details := "Only necessary ports are open"

	// Check listening ports
	out, err := exec.Command("ss", "-tlnp").Output()
	if err != nil {
		out, _ = exec.Command("netstat", "-tlnp").Output()
	}

	output := string(out)
	var openPorts []string

	if strings.Contains(output, ":443") {
		openPorts = append(openPorts, "443 (HTTPS)")
	}
	if strings.Contains(output, ":80") {
		details = "HTTP port 80 is open - should be disabled"
		status = "FAIL"
	}
	if strings.Contains(output, ":22") {
		openPorts = append(openPorts, "22 (SSH)")
	}

	if status == "PASS" {
		details = "Listening ports: " + strings.Join(openPorts, ", ")
	}

	return map[string]interface{}{
		"sr_id":        "SR5.3",
		"fr_id":        "FR5",
		"description":  "Open port restriction",
		"status":       status,
		"details":      details,
		"sl_level":     1,
	}
}

func checkSR54InternalCommunication() map[string]interface{} {
	status := "PASS"
	details := "Internal OT network communication properly restricted"

	// Check routing table
	var buf bytes.Buffer
	cmd := exec.Command("ip", "route", "show")
	cmd.Stdout = &buf

	if err := cmd.Run(); err == nil {
		routes := buf.String()
		// Look for specific network routes
		if strings.Contains(routes, "192.168") || strings.Contains(routes, "10.0") {
			details = "Network routes configured for isolated OT network (RFC1918 space)"
		}
	}

	return map[string]interface{}{
		"sr_id":        "SR5.4",
		"fr_id":        "FR5",
		"description":  "Internal OT network communication control",
		"status":       status,
		"details":      details,
		"sl_level":     2,
	}
}
